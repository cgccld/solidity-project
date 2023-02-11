// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface INFT {
    function lazyMintTransfer(
        address creator_,
        address redeemer_,
        string calldata tokenURI_
    ) external returns (bool);
}
