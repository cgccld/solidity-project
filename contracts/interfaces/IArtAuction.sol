// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IArtAuction {
    // -------------------------------- EVENT -----------------------------------
    event Started(uint256 startTime);
    event Bidded(address indexed bidder, uint256 bidAmount);
    event Claimed(address indexed bidder, uint256 bidAmount);
    event FeeClaimed(uint256 feeAmount);
    event Ended(address winner, uint256 bidAmount);

    // -------------------------------- ERROR -----------------------------------
    // error Auction__Already__Started();
    // error Auction__Already__Ended();
    // error Auction__Not__Started();
    // error Auction__Not__Ended();
    // error Not__Enough__Bid__Amount();

    function callAuction() external;

    function bid() external payable;

    function claim() external;

    function end() external;
}
