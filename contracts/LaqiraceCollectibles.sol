//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaqiraceCollectibles is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    struct CollectibleAttr {
        string name;
        string figure;
        uint256 price;
    }

    struct saleStatus {
        uint256 maxSupply;
        uint256 totalSupply;
        bool preSale;
    }

    mapping(bytes32 => CollectibleAttr) private collectibleData;
    mapping(address => mapping(bytes32 => bool)) private userPreSaleStatus;
    mapping(string => bytes32) private collectibleName;
    
    address public minter;

    bytes32[] private collectiblesSigs;
    constructor() ERC721("LaqiraceNFT", "LRNFT") {

    }
}