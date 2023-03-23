//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { NFT } from "./NFT.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract NFTFactory is Ownable {
    NFT[] public nfts;
    address implement;

    constructor(address implement_) {
        implement = implement_;
    }

    function setImplement(address newImplement_) external onlyOwner {
        implement = newImplement_;
    }

    function clone(
        address marketplace_,
        string calldata name_,
        string calldata symbol_,
        string calldata baseURI_
    ) external {
        NFT newNft = NFT(Clones.clone(implement));
        newNft.initialize(marketplace_, name_, symbol_, baseURI_);
        nfts.push(newNft);
    }

    function getClone() external view returns (NFT[] memory) {
        return nfts;
    }
}
