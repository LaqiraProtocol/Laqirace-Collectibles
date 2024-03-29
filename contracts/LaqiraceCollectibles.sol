//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./TransferHelper.sol";

interface IBEP20 {
    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */

    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract LaqiraceCollectibles is ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;
    struct CollectibleAttr {
        string name;
        string figure;
        uint256 price;
        uint256 raceCost;
        uint256 maxRaces;
    }

    struct SaleStatus {
        uint256 maxSupply;
        uint256 totalSupply;
        bool salePermit;
        bool preSale;
        bool saleByRequest;
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
    mapping(address => bool) private quoteToken;
    mapping(address => TokenIdAttr[]) private userMintRequests;
    mapping(bytes32 => bool) private collectibleSigExists;

    address private minter;
    address private mintingFeeAddress;

    bytes32[] private collectiblesSigs;
    address[] private quoteTokens;
    address[] private mintRequests;

    event ImportCollectible(string collectibleName, string figure, uint256 price, uint256 raceCost, uint256 maxRaces, bytes32 colletibleSig);
    event RemoveCollectible(bytes32 colletibleSig);
    event UpdateCollectible(string newCollectibleName, string newFigure, uint256 newPrice, uint256 newRaceCost, uint256 newMaxRaces,
    bytes32 colletibleSig);
    event RequestForMinting(address applicant, bytes32 colletibleSig, uint256 collectibleNum);
    event RechargeRequest(uint256 tokenId, address applicant, uint256 numOfRaces, uint256 cost, address quoteToken);

    function initialize(string memory _name, string memory _symbol, address _minter, address _mintingFeeAddress) public initializer {
        __ERC721_init_unchained(_name, _symbol);
        __Ownable_init_unchained();
        minter = _minter;
        mintingFeeAddress = _mintingFeeAddress;
    }

    /** WARNING: This function is only used for import a collectible for the first time.
    Any update on a collectible should be carried out by updateCollectibleAttr function.
    */
    function importCollectible(
        string memory _collectibleName,
        string memory _figure,
        uint256 _price, 
        uint256 _raceCost,
        uint256 _maxRaces) public virtual onlyOwner returns (bytes32) {
        bytes32 collectibleSig = keccak256(abi.encode(_collectibleName, _figure, _price, _raceCost, _maxRaces));
        require(!collectibleSigExists[collectibleSig], 'Collectible already exists');
        collectibleSigExists[collectibleSig] = true;
        collectibleData[collectibleSig].name = _collectibleName;
        collectibleData[collectibleSig].figure = _figure;
        collectibleData[collectibleSig].price = _price;
        collectibleData[collectibleSig].raceCost = _raceCost;
        collectibleData[collectibleSig].maxRaces = _maxRaces;

        collectiblesSigs.push(collectibleSig);
        collectibleNameToSig[_collectibleName] = collectibleSig;
        emit ImportCollectible(_collectibleName, _figure, _price, _raceCost, _maxRaces, collectibleSig);
        return collectibleSig;
    }
    
    function removeCollectible(bytes32 _collectibleSig) public virtual onlyOwner {
        require(collectibleSigExists[_collectibleSig], 'Collectible does not exist');
        delete collectibleSigExists[_collectibleSig];
        delete collectibleNameToSig[collectibleData[_collectibleSig].name];
        delete collectibleData[_collectibleSig];
        delBytes32FromArray(_collectibleSig, collectiblesSigs);
        emit RemoveCollectible(_collectibleSig);
    }

    function mintCollectible(bytes32 _collectibleSig, address _quoteToken) public virtual {
        require(saleData[_collectibleSig].salePermit, 'Minting the collectible is not permitted');
        require(!saleData[_collectibleSig].preSale, 'Minting the collectible is not allowed due to being in presale stage');
        require(!saleData[_collectibleSig].saleByRequest, 'Sale is only available by submitting request');

        require(saleData[_collectibleSig].maxSupply == 0 ||
                saleData[_collectibleSig].maxSupply > saleData[_collectibleSig].totalSupply
                , 'Max supply for the collectible was reached');

        require(quoteToken[_quoteToken], 'Payment method is not allowed');
        TransferHelper.safeTransferFrom(_quoteToken, _msgSender(), mintingFeeAddress, collectibleData[_collectibleSig].price);

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        saleData[_collectibleSig].totalSupply++;

        _mint(_msgSender(), newTokenId);
        tokenIdData[newTokenId].collectible = _collectibleSig;
        tokenIdData[newTokenId].collectibleNum = saleData[_collectibleSig].totalSupply;
    }

    function preSaleCollectible(bytes32 _collectibleSig, address _quoteToken) public virtual {
        require(saleData[_collectibleSig].salePermit, 'Minting the collectible is not permitted');
        require(saleData[_collectibleSig].preSale, 'Minting the collectible is not allowed due to being out of presale stage');
        require(!saleData[_collectibleSig].saleByRequest, 'Sale is only available by submitting request');
        require(!userPreSaleStatus[_msgSender()][_collectibleSig], 'Player has already bought the collectible in presale stage');
        
        require(saleData[_collectibleSig].maxSupply == 0 ||
                saleData[_collectibleSig].maxSupply > saleData[_collectibleSig].totalSupply
                , 'Max supply for the collectible was reached');

        require(quoteToken[_quoteToken], 'Payment method is not allowed');
        TransferHelper.safeTransferFrom(_quoteToken, _msgSender(), mintingFeeAddress, collectibleData[_collectibleSig].price);
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        saleData[_collectibleSig].totalSupply++;

        _mint(_msgSender(), newTokenId);
        userPreSaleStatus[_msgSender()][_collectibleSig] = true;
        tokenIdData[newTokenId].collectible = _collectibleSig;
        tokenIdData[newTokenId].collectibleNum = saleData[_collectibleSig].totalSupply;
    }

    function mintTo(address _to, bytes32 _collectibleSig) public virtual onlyAccessHolder {
        require(collectibleSigExists[_collectibleSig], 'Collectible does not exist');
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        saleData[_collectibleSig].totalSupply++;

        _mint(_to, newTokenId);
        tokenIdData[newTokenId].collectible = _collectibleSig;
        tokenIdData[newTokenId].collectibleNum = saleData[_collectibleSig].totalSupply;
    }

    function mintForRequest(address _to, bytes32 _collectibleSig, uint256 _collectibleNum) public virtual onlyAccessHolder {
        bool requestStatus;
        uint256 i;
        for (; userMintRequests[_to].length > i; i++) {
            if (userMintRequests[_to][i].collectible == _collectibleSig && userMintRequests[_to][i].collectibleNum == _collectibleNum) {
                requestStatus = true;
                break;
            }
        }
        require(requestStatus, 'Request not found');
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(_to, newTokenId);

        tokenIdData[newTokenId].collectible = _collectibleSig;
        tokenIdData[newTokenId].collectibleNum = _collectibleNum;
        delStructFromArray(i, userMintRequests[_to]);
        if (userMintRequests[_to].length == 0) {
            delAddressFromArray(_to, mintRequests);
        }
    }

    function requestForMint(bytes32 _collectibleSig, address _quoteToken) public virtual {
        require(saleData[_collectibleSig].salePermit, 'Minting the collectible is not permitted');
        require(saleData[_collectibleSig].saleByRequest, 'Sale is only available by submitting request');

        require(saleData[_collectibleSig].maxSupply == 0 ||
                saleData[_collectibleSig].maxSupply > saleData[_collectibleSig].totalSupply
                , 'Max supply for the collectible was reached');
        
        if (saleData[_collectibleSig].preSale) {
             require(!userPreSaleStatus[_msgSender()][_collectibleSig], 'Player has already bought the collectible in presale stage');
        }

        require(quoteToken[_quoteToken], 'Payment method is not allowed');
        TransferHelper.safeTransferFrom(_quoteToken, _msgSender(), mintingFeeAddress, collectibleData[_collectibleSig].price);
        
        saleData[_collectibleSig].totalSupply++;

        TokenIdAttr[] storage requests;
        TokenIdAttr memory request;
        request.collectible = _collectibleSig;
        request.collectibleNum = saleData[_collectibleSig].totalSupply;

        requests = userMintRequests[_msgSender()];
        requests.push(request);
        userMintRequests[_msgSender()] = requests;
        mintRequests.push(_msgSender());

        if (saleData[_collectibleSig].preSale) {
            userPreSaleStatus[_msgSender()][_collectibleSig] = true;
        }
        emit RequestForMinting(_msgSender(), _collectibleSig, saleData[_collectibleSig].totalSupply);
    }

    function updateCollectibleAttr(bytes32 _collectibleSig,
    string memory _name,
    string memory _figure,
    uint256 _price,
    uint256 _raceCost,
    uint256 _maxRaces) public virtual onlyOwner {
        require(collectibleSigExists[_collectibleSig], 'Collectible does not exist');
        
        delete collectibleNameToSig[collectibleData[_collectibleSig].name];
        
        collectibleData[_collectibleSig].name = _name;
        collectibleData[_collectibleSig].figure = _figure;
        collectibleData[_collectibleSig].price = _price;
        collectibleData[_collectibleSig].raceCost = _raceCost;
        collectibleData[_collectibleSig].maxRaces = _maxRaces;
        
        collectibleNameToSig[_name] = _collectibleSig;
        emit UpdateCollectible(_name, _figure, _price, _raceCost, _maxRaces, _collectibleSig);
    }

    function setSaleStatus(bytes32 _collectibleSig,
    uint256 _maxSupply,
    bool _salePermit,
    bool _preSale,
    bool _saleByRequest) public virtual onlyOwner {
        require(collectibleSigExists[_collectibleSig], 'Collectible does not exist');
        saleData[_collectibleSig].maxSupply = _maxSupply;
        saleData[_collectibleSig].salePermit = _salePermit;
        saleData[_collectibleSig].preSale = _preSale;
        saleData[_collectibleSig].saleByRequest = _saleByRequest;
    }

    function updateMinter(address _newMinter) public virtual onlyOwner {
        minter = _newMinter;
    }

    function updateMintingFeeAddress(address _newMintingFeeAddress) public virtual onlyOwner {
        mintingFeeAddress = _newMintingFeeAddress;
    }

    function addQuoteToken(address _quoteToken) public virtual onlyOwner {
        quoteToken[_quoteToken] = true;
        quoteTokens.push(_quoteToken);
    }

    function removeQuoteToken(address _quoteToken) public virtual onlyOwner {
        delete quoteToken[_quoteToken];
        delAddressFromArray(_quoteToken, quoteTokens);
    }

    function transferAnyBEP20(address _tokenAddress, address _to, uint256 _amount) public virtual onlyOwner {
        IBEP20(_tokenAddress).transfer(_to, _amount);
    }

    function adminWithdrawal(uint256 _amount) public virtual onlyOwner {
        address payable _owner = payable(owner());
        _owner.transfer(_amount);
    }

    function transfer(address _to, uint256 _tokenId) public virtual {
        _transfer(_msgSender(), _to, _tokenId);
    }

    function burn(uint256 _tokenId) public virtual onlyAccessHolder {
        _burn(_tokenId);
    }

    function requestChargeCollectible(uint256 _tokenId, uint256 _numOfRaces, address _quoteToken) public virtual {
        require(_exists(_tokenId), 'tokenId does not exist');
        require(_numOfRaces <= collectibleData[tokenIdData[_tokenId].collectible].maxRaces, 'Number of races is more than max allowed races');
        require(quoteToken[_quoteToken], 'Payment method is not allowed');
        bytes32 _collectibleSig = tokenIdData[_tokenId].collectible;
        uint256 _cost = _numOfRaces * collectibleData[_collectibleSig].raceCost;
        TransferHelper.safeTransferFrom(_quoteToken, _msgSender(), mintingFeeAddress, _cost);
        emit RechargeRequest(_tokenId, _msgSender(), _numOfRaces, _cost, _quoteToken);
    }


    function getCollectibleData(bytes32 _collectibleSig) public virtual view returns (CollectibleAttr memory) {
        return collectibleData[_collectibleSig];
    }

    function getCollectibleSaleData(bytes32 _collectibleSig) public virtual view returns (SaleStatus memory) {
        return saleData[_collectibleSig];
    }
    
    function getCollectibleSigByName(string memory _collectibleName) public virtual view returns (bytes32) {
        return collectibleNameToSig[_collectibleName];
    }

    function getTokenIdAttr(uint256 _tokenId) public virtual view returns (TokenIdAttr memory) {
        return tokenIdData[_tokenId];
    }

    function getUserPreSaleStatus(address _user, string memory _collectibleName) public virtual view returns (bool) {
        return userPreSaleStatus[_user][collectibleNameToSig[_collectibleName]];
    }

    function getCollectiblesSigs() public virtual view returns (bytes32[] memory) {
        return collectiblesSigs;
    }

    function getQuoteTokens() public virtual view returns (address[] memory) {
        return quoteTokens;
    }

    function getMinter() public virtual view returns (address) {
        return minter;
    }

    function getMintingFeeAddress() public virtual view returns (address) {
        return mintingFeeAddress;
    }

    function getUserMintRequest(address _user) public virtual view returns (TokenIdAttr[] memory) {
        return userMintRequests[_user];
    }

    function getMintRequests() public virtual view returns (address[] memory) {
        return mintRequests;
    }

    function delAddressFromArray(
        address _element,
        address[] storage array
    ) internal virtual {
        // delete the element
        uint256 len = array.length;
        uint256 j = 0;
        for (uint256 i = 0; i <= len - 1; i++) {
            if (array[i] == _element) {
                j = i;
                break;
            }
        }
        for (j; j < len - 1; j++) {
            array[j] = array[j + 1];
        }
        array.pop();
    }
    
    function delBytes32FromArray(
        bytes32 _element,
        bytes32[] storage array
    ) internal virtual {
        // delete the element
        uint256 len = array.length;
        uint256 j = 0;
        for (uint256 i = 0; i <= len - 1; i++) {
            if (array[i] == _element) {
                j = i;
                break;
            }
        }
        for (j; j < len - 1; j++) {
            array[j] = array[j + 1];
        }
        array.pop();
    }

    function delStructFromArray(
        uint256 i,
        TokenIdAttr[] storage array
    ) internal virtual {
        uint256 len = array.length;
        for (i; i < len - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
    }

    modifier onlyAccessHolder() {
        require(_msgSender() == owner() || _msgSender() == minter, 'Permission denied');
        _;
    }
}
