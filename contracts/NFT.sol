// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { INFT } from "./interfaces/INFT.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ERC721EnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { ERC721URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

contract NFT is
    INFT,
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    UUPSUpgradeable
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
        address marketplace_,
        string calldata name_,
        string calldata symbol_,
        string calldata baseURI_
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        baseURI = baseURI_;
        marketplace = marketplace_;
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
    ) internal virtual override {
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

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _burn(
        uint256 tokenId
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
