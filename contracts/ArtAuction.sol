// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IArtAuction } from "./interfaces/IArtAuction.sol";

contract ArtAuction is IArtAuction {
    IERC721 public token;
    bool public started;
    uint256 public tokenId;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public highestBid;
    address public highestBidder;
    address payable public vault;
    address public owner;
    mapping(address => uint256) bids;

    constructor(
        address token_,
        uint256 tokenId_,
        uint256 startingBid_
    ) payable {
        token = IERC721(token_);
        tokenId = tokenId_;
        owner = address(this);
        highestBid = startingBid_;
        vault = payable(msg.sender);
    }

    function callAuction() external onlyNotStart {
        token.safeTransferFrom(msg.sender, owner, tokenId);
        started = true;
        startTime = block.timestamp;
        endTime = startTime + 7 days;
        emit Started(startTime);
    }

    function bid()
        external
        payable
        onlyBeforeEnd
        onlyStart
        onlyEOA(msg.sender)
    {
        require(msg.value > highestBid, "NOT_ENOUGH_BID_AMOUNT");
        bids[highestBidder] += highestBid;
        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bidded(highestBidder, highestBid);
    }

    function claim() external onlyAfterEnd {
        uint balance = bids[msg.sender];
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(balance);

        emit Claimed(msg.sender, bids[msg.sender]);
    }

    function end() external onlyStart onlyAfterEnd {
        token.safeTransferFrom(owner, highestBidder, tokenId);
        emit Ended(highestBidder, highestBid);
    }

    modifier onlyAfterEnd() {
        require(block.timestamp < endTime, "AUCTION_NOT_ENDED");
        _;
    }

    modifier onlyBeforeEnd() {
        require(block.timestamp > endTime, "AUCTION_ALREADY_ENDED");
        _;
    }

    modifier onlyStart() {
        require(started, "AUCTION_NOT_STARTED");
        _;
    }

    modifier onlyNotStart() {
        require(!started, "AUCTION_ALREADY_STARTED");
        _;
    }

    modifier onlyEOA(address sender_) {
        require(
            !(sender_ == address(0) || sender_.code.length == 0),
            "INVALID_EOA"
        );
        _;
    }
}
