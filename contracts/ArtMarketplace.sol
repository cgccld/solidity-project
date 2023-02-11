// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ERC721, IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC1155, IERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { INFT } from "./interfaces/INFT.sol";
import { ISemiNFT } from "./interfaces/ISemiNFT.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { IMarketplace } from "./interfaces/IMarketplace.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract ArtMarketplace is IMarketplace, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ERC165Checker for address;

    bytes32 public constant WRONG_CALL =
        0xb66bb11815392dc0f2faeca1c34bd40e0212a81b5fde1e3837180e783b177006;

    IPriceOracle public immutable priceOracle;
    AggregatorV3Interface public immutable priceFeed;

    uint256 public feePercent;

    mapping(address => bool) public isBanned;
    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public supportedPayments;

    constructor(
        address owner_,
        uint256 feePercent_,
        IPriceOracle priceOracle_,
        AggregatorV3Interface priceFeed_
    ) Ownable() Pausable() ReentrancyGuard() {
        priceFeed = priceFeed_;
        priceOracle = priceOracle_;

        _setFee(feePercent_);
        _transferOwnership(owner_);
    }

    function setFee(uint256 feePercent_) external onlyOwner {
        _setFee(feePercent_);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function buyLazyMint(
        Order calldata order_
    ) external payable whenNotPaused nonReentrant {
        _checkBanned(_msgSender());
        _checkAddress(order_);

        // 1 token -> unitPriceByUSD
        // ? token <- usdPrice
        _processPayment(
            (order_.sale.payments.usdPrice * 1 ether) /
                priceOracle.usdPrice(order_.option.token),
            order_
        );

        (bool success, bytes memory returnData) = order_
            .sale
            .item
            .tokenAddress
            .call(_lazyMintCalldata(order_.sale.item));

        require(success, "EXECUTION_FAILED");
        require(abi.decode(returnData, (bool)), "LAZY_MINT_FAILED");

        emit Redeemed(
            order_.sale.taker,
            order_.maker,
            order_.sale.item.tokenInfo
        );
    }

    // function _checkBanned(address account) internal view virtual {
    //     return
    // }

    function _checkAddress(Order calldata order_) internal view virtual {
        require(
            supportedTokens[order_.sale.item.tokenAddress],
            "UNSUPPORTED_TOKEN"
        );
        require(supportedPayments[order_.option.token], "UNSUPPORTED_PAYMENT");
    }

    function _setFee(uint256 feePercent_) internal virtual {
        emit FeeSet(feePercent, feePercent_);

        feePercent = feePercent_;
    }

    function _processPayment(
        uint256 amount_,
        Order calldata order_
    ) internal virtual {
        uint256 fee = (amount_ * feePercent) / percentageFraction();
        uint256 payout = amount_ + fee;
        if (order_.option.token != address(0)) {
            if (
                IERC20(order_.option.token).allowance(
                    order_.maker,
                    address(this)
                ) < payout
            ) {
                (uint8 v, bytes32 r, bytes32 s) = abi.decode(
                    order_.option.signature,
                    (uint8, bytes32, bytes32)
                );
                IERC20Permit(order_.option.token).permit(
                    order_.maker,
                    address(this),
                    payout,
                    order_.option.deadline,
                    v,
                    r,
                    s
                );
            }

            IERC20(order_.option.token).safeTransferFrom(
                order_.maker,
                order_.sale.taker,
                amount_
            );

            /// chuyen cjo san
        } else {
            require(payout <= msg.value, "INSUFFICIENT_AMOUNT");

            bool sent;
            (sent, ) = order_.sale.taker.call{ value: amount_ }("");

            emit NativeTransfered({
                from: _msgSender(),
                to: order_.sale.taker,
                isRefund: false,
                amount: amount_
            });

            require(sent, "SENT_FAILED");

            // chuyen cho san

            if (payout < msg.value) {
                uint256 refundAmt = msg.value - payout;
                (sent, ) = order_.sale.taker.call{ value: refundAmt }("");

                require(sent, "REFUND_FAILED");

                emit NativeTransfered({
                    from: address(this),
                    to: order_.maker,
                    isRefund: true,
                    amount: refundAmt
                });
            }
        }
    }

    function _lazyMintCalldata(
        Item calldata item_
    ) internal view virtual returns (bytes memory) {
        if (item_.tokenAddress.supportsInterface(type(INFT).interfaceId)) {
            (address creator, address redeemer, string memory tokenURI) = abi
                .decode(item_.tokenInfo, (address, address, string));
            return
                abi.encodeCall(
                    INFT.lazyMintTransfer,
                    (creator, redeemer, tokenURI)
                );
        } else if (
            item_.tokenAddress.supportsInterface(type(ISemiNFT).interfaceId)
        ) {
            (
                address creator,
                address redeemer,
                uint256 amount,
                string memory tokenURI
            ) = abi.decode(
                    item_.tokenInfo,
                    (address, address, uint256, string)
                );
            return
                abi.encodeCall(
                    ISemiNFT.lazyMintTransfer,
                    (creator, redeemer, amount, tokenURI)
                );
        }

        return abi.encode(WRONG_CALL);
    }

    function percentageFraction() public pure virtual returns (bool) {
        return 10_000;
    }
}
