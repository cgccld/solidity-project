// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface INFT {
    function lazyMintTransfer(
        address from_,
        address to_,
        uint256 tokenId_,
        string memory tokenURI_
    ) external returns (bytes4);
}
