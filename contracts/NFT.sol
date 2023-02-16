// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { INFT } from "./interfaces/INFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";

contract NFT is INFT, ERC721, Pausable, Ownable {
    string private _name;
    string private _symbol;
    string private baseURI;
    address public marketplace;

    mapping(uint256 => string) public tokenURIs;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) Ownable() Pausable() ERC721(name_, symbol_) {
        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _setTokenURI(
        uint256 tokenId_,
        string memory tokenURI_
    ) internal virtual {
        require(_exists(tokenId_), "NONEXISTENT_TOKEN");
        tokenURIs[tokenId_] = tokenURI_;
    }

    modifier onlyMarketplace(address sender) {
        require(marketplace == sender);
        _;
    }

    function lazyMintTransfer(
        address from_,
        address to_,
        uint256 tokenId_,
        string memory tokenURI_
    ) external onlyMarketplace(_msgSender()) returns (bytes4) {
        _safeMint(from_, tokenId_);
        if (bytes(tokenURI_).length != 0) _setTokenURI(tokenId_, tokenURI_);
        _safeTransfer(from_, to_, tokenId_, "");

        return INFT.lazyMintTransfer.selector;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
