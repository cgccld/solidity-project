// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {INFT} from "./interfaces/INFT.sol";
import {IArtAuction} from "./interface/IArtAuction.sol";


contract ArtAuction {
    INFT public token;
    bool public started;
    uint256 public tokenId;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public highestBid;
    address public highestBidder;
    address payables public vault;
    address public owner;
    mapping(address => uint256) bids;
    
    constructor(address token_, uint256 tokenId_, uint256 startingBid_) {
        token = token_;
        tokenId = tokenId_;
        owner = address(this);
        highestBid = startingBid_;
        vault = payable(msg.sender);
    }

    modifier onlyAfter() {
        require(block.timestamp > endTime, Auction__Not__Ended());
        _;
    }

    modifier onlyBefore() {
        require(block.timestamp > endTime, Auction__Already__Ended());
        _;
    }

    modifier onlyStart() {
        require(started, Auction__Not__Started());
        _;
    }

    modifier onlyNotStart() {
        require(!started, Auction__Already__Started());
        _;
    }
    
    modifier onlyEOA(address sender_) {
        require(
            !(sender == address(0) ||
            sender.code.length == 0),
            "Invalid EOA"
        )
    }


    function callAuction() external onlyNotStart {
        token.safeTransferFrom(_msgSender(), owner, tokenId);
        started = true;
        startTime = block.timestamp;
        endTime = startTime + 7 days;
        emit Started(startTime);
    }

    function bit() external payable onlyBefore onlyStart onlyEOA(msg.sender){
        require(msg.value > highestBid, Not__Enough__Bid__Amount());
        bids[highestBidder] += highestBid;
        highestBidder = _msgSender();
        highestBid = msg.value;

        emit Bidded(highestBidder, highestBid);
    }

    function claim() external onlyAfter {
        uint balance = bids[_msgSender()];
        bids[_msgSender()] = 0;
        payable(_msgSender()).transfer(balance);

        emit Claimed(_msgSender(), bits[_msgSender()]);
    }

    function end() external onlyStart onlyAfter {
        nft.safeTransferFrom(owner, highestBidder, tokenId);
        emit Ended(highestBidder, highestBid);
    }
}