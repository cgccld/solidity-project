// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import { ISemiNFT } from "./interfaces/ISemiNFT.sol";

contract SemiNFT is ERC1155, Ownable, Pausable {
    string private _name;
    string private _symbol;
    string private baseURI;
    address public marketplace;

    mapping(uint256 => string) public tokenURIs;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) Ownable() Pausable() ERC1155("") {
        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;
    }

    modifier onlyMarketplace(address sender) {
        require(marketplace == sender);
        _;
    }

    function lazyMintTransfer(
        address from_,
        address to_,
        uint256 tokenId_,
        uint256 amount_,
        string memory tokenURI_
    ) external onlyMarketplace(_msgSender()) returns (bytes4) {
        _mint(from_, tokenId_, amount_, "");
        _setTokenURI(tokenId_, tokenURI_);
        _safeTransferFrom(from_, to_, tokenId_, amount_, "");

        return ISemiNFT.lazyMintTransfer.selector;
    }

    function setURI(string memory newURI_) public onlyOwner {
        _setURI(newURI_);
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
        tokenURIs[tokenId_] = tokenURI_;
    }
}
