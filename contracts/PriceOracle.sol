// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {
    AggregatorV3Interface internal priceFeed;

    mapping(address => uint256) tokenPriceUSD;

    constructor() {
        // BNB / USD
        priceFeed = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );
    }

    function getNativeTokenPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();

        return uint256(price) / 10 ** priceFeed.decimals();
    }

    function setPrice(address token_, uint256 newPrice_) external {
        tokenPriceUSD[token_] = newPrice_;
    }

    function usdPrice(address token_) external view returns (uint256) {
        if (token_ == address(0)) {
            return getNativeTokenPrice();
        } else {
            require(tokenPriceUSD[token_] != 0, "ZERO_PRICE");
            return tokenPriceUSD[token_];
        }
    }
}
