// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPriceOracle {
    function usdPrice(address token_) external view returns (uint256);
}
