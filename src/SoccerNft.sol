// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721URIStorage {
    uint256 private _tokenIds;
    address private _baseTokenURI;

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) {}

    function mintNFT(string memory tokenURI) public returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.filebase.io/ipfs/QmPTEaHudXURDcCxieZmujGbDRHFqYmMJzUUr9shmLtwns/";
    }
}