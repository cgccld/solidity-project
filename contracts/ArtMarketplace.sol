// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { ERC721Upgradeable, IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { ERC1155Upgradeable, IERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

import { INFT } from "./interfaces/INFT.sol";
import { ISemiNFT } from "./interfaces/ISemiNFT.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { IMarketplace } from "./interfaces/IMarketplace.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20PermitUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ERC165CheckerUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";

contract ArtMarketplace is
    IMarketplace,
    Initializable,
    UUPSUpgradeable,
    EIP712Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ERC165CheckerUpgradeable for address;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant WRONG_CALL =
        0xb66bb11815392dc0f2faeca1c34bd40e0212a81b5fde1e3837180e783b177006;

    ///@dev Value is equal to keccak256("Order(address maker, Sale sale, PaymentOption option)Sale(address taker, Item item, Payment payments, uint256 nonce, uint256 deadline)PaymentOption(address token, uint256 amount, uint256 deadline, bytes signature)Item(address tokenAddress, uint256 deadline, bytes tokenInfo, bytes message, bytes signature)Payment(uint256 usdPrice, address[] payments)")
    bytes32 private constant ORDER_TYPE_HASH =
        0x9523aab5e62cf8b2ad9770ab7f181e55c8e51b4f17a4f4dcc40affca9b3a38cc;

    ///@dev Value is equal to keccak256("Item(address tokenAddress, uint256 deadline, bytes tokenInfo, bytes message, bytes signature)")
    bytes32 private constant ITEM_TYPE_HASH =
        0xce289cb5e643a21ee82f1b0493e655b4d2de93f8e72116a325f203cdf085b814;

    ///@dev Value is equal to keccak256("Sale(address taker, Item item, Payment payments, uint256 nonce, uint256 deadline)Item(address tokenAddress, uint256 deadline, bytes tokenInfo, bytes message, bytes signature)Payment(uint256 usdPrice, address[] payments)")
    bytes32 private constant SALE_TYPE_HASH =
        0x38a6e7a7ed211fcffb45e7b6f5e9ea53adcfeead28902688e64e896fed72e4d8;

    ///@dev Value is equal to keccak256("Payment(uint256 usdPrice, address[] payments)")
    bytes32 private constant PAYMENT_TYPE_HASH =
        0x5dec49e0115fe4c01c3667994836128bf09a7e9ad87ad22a9f5025a2c1c676ba;

    ///@dev Value is equal to keccak256("PaymentOption(address token, uint256 amount, uint256 deadline, bytes signature)")
    bytes32 private constant PAYMENT_OPTION_TYPE_HASH =
        0x1c301dfb0ebce365552ccf106202212b2e83e6722705d40ea38ecb8d66bcb0f0;

    IPriceOracle public priceOracle;

    uint256 public feePercent;

    mapping(address => bool) public isBanned;
    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public supportedPayments;
    mapping(address => CountersUpgradeable.Counter) public nonces;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        uint256 feePercent_,
        IPriceOracle priceOracle_
    ) public initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __EIP712_init("ArtMarketplace", "1");

        priceOracle = priceOracle_;
        _setFee(feePercent_);
        _transferOwnership(owner_);
    }

    function setFee(uint256 feePercent_) external onlyOwner {
        _setFee(feePercent_);
    }

    function setBan(address account_) external onlyOwner {
        _setBan(account_);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function buyLazyMint(
        Order calldata order_,
        bytes calldata signature_
    ) external payable whenNotPaused nonReentrant {
        bytes32 digest = _hashTypedDataV4(_hash(order_));
        address signer = ECDSAUpgradeable.recover(digest, signature_);
        require(signer == order_.sale.taker, "INVALID_SIGNATURE");

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

    function _hash(Order calldata order_) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPE_HASH,
                    __hashSale(order_.sale),
                    __hashPaymentOption(order_.option)
                )
            );
    }

    function _checkBanned(address account_) internal view virtual {
        require(isBanned[account_], "USER_WAS_BANNED");
    }

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

    function _setBan(address account_) internal virtual {
        emit BanSet(account_, true);

        isBanned[account_] = true;
    }

    function _processPayment(
        uint256 amount_,
        Order calldata order_
    ) internal virtual {
        uint256 fee = (amount_ * feePercent) / percentageFraction();
        uint256 payout = amount_ + fee;
        if (order_.option.token != address(0)) {
            if (
                IERC20Upgradeable(order_.option.token).allowance(
                    order_.maker,
                    address(this)
                ) < payout
            ) {
                (uint8 v, bytes32 r, bytes32 s) = abi.decode(
                    order_.option.signature,
                    (uint8, bytes32, bytes32)
                );
                IERC20PermitUpgradeable(order_.option.token).permit(
                    order_.maker,
                    address(this),
                    payout,
                    order_.option.deadline,
                    v,
                    r,
                    s
                );
            }

            IERC20Upgradeable(order_.option.token).safeTransferFrom(
                order_.maker,
                order_.sale.taker,
                amount_
            );

            /// chuyen cjo san
            IERC20Upgradeable(order_.option.token).safeTransferFrom(
                order_.maker,
                address(this),
                fee
            );
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
            (sent, ) = address(this).call{ value: fee }("");

            emit NativeTransfered({
                from: _msgSender(),
                to: address(this),
                isRefund: false,
                amount: fee
            });

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
            (
                address from,
                address to,
                uint256 tokenId,
                string memory tokenURI
            ) = abi.decode(
                    item_.tokenInfo,
                    (address, address, uint256, string)
                );
            return
                abi.encodeCall(
                    INFT.lazyMintTransfer,
                    (from, to, tokenId, tokenURI)
                );
        } else if (
            item_.tokenAddress.supportsInterface(type(ISemiNFT).interfaceId)
        ) {
            (
                address from,
                address to,
                uint256 tokenId,
                uint256 amount,
                string memory tokenURI
            ) = abi.decode(
                    item_.tokenInfo,
                    (address, address, uint256, uint256, string)
                );
            return
                abi.encodeCall(
                    ISemiNFT.lazyMintTransfer,
                    (from, to, tokenId, amount, tokenURI)
                );
        }

        return abi.encode(WRONG_CALL);
    }

    function percentageFraction() public pure virtual returns (uint256) {
        return 10_000;
    }

    function __hashItem(Item calldata item_) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ITEM_TYPE_HASH,
                    item_.tokenAddress,
                    item_.deadline,
                    item_.tokenInfo,
                    item_.message,
                    keccak256(bytes(item_.signature))
                )
            );
    }

    function __hashSale(Sale calldata sale_) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    SALE_TYPE_HASH,
                    sale_.taker,
                    __hashItem(sale_.item),
                    __hashPayment(sale_.payments),
                    sale_.nonce,
                    sale_.deadline
                )
            );
    }

    function __hashPayment(
        Payment calldata payment_
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PAYMENT_TYPE_HASH,
                    payment_.usdPrice,
                    payment_.payments
                )
            );
    }

    function __hashPaymentOption(
        PaymentOption calldata paymentOption_
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PAYMENT_OPTION_TYPE_HASH,
                    paymentOption_.token,
                    paymentOption_.amount,
                    paymentOption_.deadline,
                    keccak256(bytes(paymentOption_.signature))
                )
            );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
