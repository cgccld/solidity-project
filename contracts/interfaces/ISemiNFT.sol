// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISemiNFT {
    function lazyMintTransfer(
        address from_,
        address to_,
        uint256 tokenId_,
        uint256 amount_,
        string memory tokenURI_
    ) external returns (bytes4);
}
