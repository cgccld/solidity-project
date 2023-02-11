// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISemiNFT {
    function lazyMintTransfer(
        address creater_,
        address redeemer_,
        uint256 amount_,
        string calldata tokenURI_
    ) external returns (bool);
}
