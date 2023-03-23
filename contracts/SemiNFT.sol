// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ISemiNFT } from "./interfaces/ISemiNFT.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract SemiNFT is
    Initializable,
    UUPSUpgradeable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    string private _name;
    string private _symbol;
    string private baseURI;
    address public marketplace;

    mapping(uint256 => string) public tokenURIs;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string calldata name_,
        string calldata symbol_,
        string calldata baseURI_,
        address marketplace_
    ) public initializer {
        __ERC1155_init(_name);
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;
        marketplace = marketplace_;
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

    function _setTokenURI(
        uint256 tokenId_,
        string memory tokenURI_
    ) internal virtual {
        tokenURIs[tokenId_] = tokenURI_;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
