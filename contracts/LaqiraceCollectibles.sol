//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaqiraceCollectibles is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    struct CollectiableAttr {
        string name;
        string figure;
        uint256 price;
    }

    struct saleStatus {
        uint256 maxSupply;
        uint256 totalSupply;
        bool preSale;
    }

    constructor() ERC721("LaqiraceNFT", "LRNFT") {

    }

}