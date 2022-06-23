//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./TransferHelper.sol";

contract LaqiraceCollectibles is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    struct CollectibleAttr {
        string name;
        string figure;
        uint256 price;
    }

    struct SaleStatus {
        uint256 maxSupply;
        uint256 totalSupply;
        bool salePermit;
        bool preSale;
    }

    struct TokenIdAttr {
        bytes32 collectible;
        uint256 collectibleNum;
    }

    mapping(bytes32 => CollectibleAttr) private collectibleData;
    mapping(bytes32 => SaleStatus) private saleData;
    mapping(address => mapping(bytes32 => bool)) private userPreSaleStatus;
    mapping(string => bytes32) private collectibleName;
    mapping(uint256 => TokenIdAttr) private tokenIdData;

    address public minter;

    bytes32[] private collectiblesSigs;
    constructor() ERC721("LaqiraceNFT", "LRNFT") {

    }

    function importCollectible(
        string memory _collectibleName,
        string memory _figure,
        uint256 _price) public onlyOwner returns (bytes32 collectibleSignature) {
        bytes32 collectibleSig = keccak256(abi.encodePacked(_collectibleName, _figure, _price));
        collectibleData[collectibleSig].name = _collectibleName;
        collectibleData[collectibleSig].figure = _figure;
        collectibleData[collectibleSig].price = _price;

        collectiblesSigs.push(collectibleSig);
        collectibleName[_collectibleName] = collectibleSig;
        return collectibleSig;
    }
}