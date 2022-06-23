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
    mapping(string => bytes32) private collectibleNameToSig;
    mapping(uint256 => TokenIdAttr) private tokenIdData;
    mapping(address => bool) private qouteToken;

    address public minter;
    address public mintingFeeAddress;

    bytes32[] private collectiblesSigs;
    constructor(address _minter, address _mintingFeeAddress) ERC721("LaqiraceNFT", "LRNFT") {
        minter = _minter;
        mintingFeeAddress = _mintingFeeAddress;
    }

    /** WARNING: This function is only used for import a collectible for the first time.
    Any update on a collectible should be carried out by updateCollectibleAttr function.
    */
    function importCollectible(
        string memory _collectibleName,
        string memory _figure,
        uint256 _price) public onlyOwner returns (bytes32 collectibleSignature) {
        bytes32 collectibleSig = keccak256(abi.encodePacked(_collectibleName, _figure, _price));
        collectibleData[collectibleSig].name = _collectibleName;
        collectibleData[collectibleSig].figure = _figure;
        collectibleData[collectibleSig].price = _price;

        collectiblesSigs.push(collectibleSig);
        collectibleNameToSig[_collectibleName] = collectibleSig;
        return collectibleSig;
    }

    function mintCollectible(bytes32 _collectibleSig, address _quoteToken) public {
        if (_msgSender() == minter) {
        } else {
            require(saleData[_collectibleSig].maxSupply == 0 ||
            saleData[_collectibleSig].maxSupply > saleData[_collectibleSig].totalSupply
            , 'Max supply for the collectible was reached');
        }

        require(saleData[_collectibleSig].salePermit, 'Minting the collectible is not permitted');
        require(!saleData[_collectibleSig].preSale, 'Minting the collectible is not allowed due to being in presale stage');

        if (_msgSender() == minter) {
        } else {
            require(qouteToken[_quoteToken], 'Payment method is not allowed');
            TransferHelper.safeTransferFrom(_quoteToken, _msgSender(), mintingFeeAddress, collectibleData[_collectibleSig].price);
        }
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        saleData[_collectibleSig].totalSupply++;

        _mint(_msgSender(), newTokenId);
        tokenIdData[newTokenId].collectible = _collectibleSig;
        tokenIdData[newTokenId].collectibleNum = saleData[_collectibleSig].totalSupply;
    }

    function preSaleCollectible(bytes32 _collectibleSig, address _quoteToken) public {
        if (_msgSender() == minter) {
        } else {
            require(saleData[_collectibleSig].maxSupply == 0 ||
            saleData[_collectibleSig].maxSupply > saleData[_collectibleSig].totalSupply
            , 'Max supply for the collectible was reached');
        }

        require(saleData[_collectibleSig].salePermit, 'Minting the collectible is not permitted');
        require(saleData[_collectibleSig].preSale, 'Minting the collectible is not allowed due to being out of presale stage');
        require(!userPreSaleStatus[_msgSender()][_collectibleSig], 'Player has already bought the collectible in presale stage');

        if (_msgSender() == minter) {
        } else {
            require(qouteToken[_quoteToken], 'Payment method is not allowed');
            TransferHelper.safeTransferFrom(_quoteToken, _msgSender(), mintingFeeAddress, collectibleData[_collectibleSig].price);
        }
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        saleData[_collectibleSig].totalSupply++;

        _mint(_msgSender(), newTokenId);
        userPreSaleStatus[_msgSender()][_collectibleSig] = true;
        tokenIdData[newTokenId].collectible = _collectibleSig;
        tokenIdData[newTokenId].collectibleNum = saleData[_collectibleSig].totalSupply;
    }

    function updateCollectibleAttr(bytes32 _collectibleSig,
    string memory _name,
    string memory _figure,
    uint256 _price) public onlyOwner returns (bool) {
        collectibleData[_collectibleSig].name = _name;
        collectibleData[_collectibleSig].figure = _figure;
        collectibleData[_collectibleSig].price = _price;
        
        delete collectibleNameToSig[collectibleData[_collectibleSig].name];
        collectibleNameToSig[_name] = _collectibleSig;
        return true;
    }

    function setSaleStatus(bytes32 _collectibleSig,
    uint256 _maxSupply,
    bool _salePermit,
    bool _preSale) public onlyOwner returns (bool) {
        saleData[_collectibleSig].maxSupply = _maxSupply;
        saleData[_collectibleSig].salePermit = _salePermit;
        saleData[_collectibleSig].preSale = _preSale;
        return true;
    }

    function updateMinter(address _newMinter) public onlyOwner returns (bool) {
        minter = _newMinter;
        return true;
    }

    function updateMintingFeeAddress(address _newMintingFeeAddress) public onlyOwner returns (bool) {
        mintingFeeAddress = _newMintingFeeAddress;
        return true;
    }

    function addQuoteToken(address _quoteToken) public onlyOwner returns (bool) {
        qouteToken[_quoteToken] = true;
        return true;
    }

    function removeQuoteToken(address _quoteToken) public onlyOwner returns (bool) {
        delete qouteToken[_quoteToken];
        return true;
    }

    function getCollectibleData(bytes32 _collectibleSig) public view returns (CollectibleAttr memory) {
        return collectibleData[_collectibleSig];
    }

    function getCollectibleSaleData(bytes32 _collectibleSig) public view returns (SaleStatus memory) {
        return saleData[_collectibleSig];
    }

    function getTokenIdAttr(uint256 _tokenId) public view returns (TokenIdAttr memory) {
        return tokenIdData[_tokenId];
    }
}