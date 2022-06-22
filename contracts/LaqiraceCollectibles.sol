//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaqiraceCollectibles is ERC721Enumerable, Ownable {

    constructor() ERC721("LaqiraceNFT", "LRNFT") {}
}