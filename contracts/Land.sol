pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {ERC721Burnable} from "./ERC721Burnable.sol";
import {ERC721} from "./ERC721.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol"; 
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Decimal} from "./Decimal.sol";
import {ILandExchange} from "./interfaces/ILandExchange.sol";
import "./interfaces/ILand.sol";
import {ISpace} from "./interfaces/ISpace.sol";
import "./interfaces/ISpace.sol";

contract Land is ILand, ERC721Burnable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
 
 	 address public landExchangeContract; 
    address public spaceContract;
    address public landOperatorAddress;
    uint256 public maxSupply = 10000;//10K Parcels
 
    mapping(uint256 => address) public previousTokenOwners; 
    mapping(uint256 => address) public tokenCreators; 
    mapping(address => EnumerableSet.UintSet) private _creatorTokens; 
    mapping(uint256 => bytes32) public tokenContentHashes; 
    mapping(uint256 => bytes32) public tokenMetadataHashes;  
    mapping(uint256 => string) private _tokenMetadataURIs; 
    mapping(bytes32 => bool) private _contentHashes;  
    mapping(uint256 => int) public tokenXCoordinates;  
    mapping(uint256 => int) public tokenYCoordinates;  
    mapping(uint256 => uint256) public tokenSpaces; 

    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0xc904b9c6;  

    Counters.Counter private _tokenIdTracker;

    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Land: nonexistent token");
        _;
    }

    modifier onlyTokenWithContentHash(uint256 tokenId) {
        require(
            tokenContentHashes[tokenId] != 0,
            "Land: token does not have hash of created content"
        );
        _;
    }

    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "Land: token does not have hash of its metadata"
        );
        _;
    }

    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Land: Only approved or owner"
        );
        _;
    }

    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            _tokenIdTracker.current() > tokenId,
            "Land: token with that id does not exist"
        );
        _;
    }

    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "Land: specified uri must be non-empty"
        );
        _;
    }

    modifier onlyValidSpace(address spender,uint256 spaceTokenId) {
        bool spaceAttachable =  ISpace(spaceContract).checkLandAttach(spaceTokenId,spender);
        require(
            spaceAttachable == true,
            "Land: space is not attachble to land"
        );
        _; 
    }
    modifier onlyEmptyLand(uint256 tokenId) {
        require(
            tokenSpaces[tokenId] == uint256(0x0),
            "Land: land should be empty"
        );
        _; 
    }
 
    constructor(address landExchangeContractAddr, address spaceContractAddr, address landOperatorAddr) 
        public 
        ERC721("Motif LAND","LAND") {
        landExchangeContract = landExchangeContractAddr;
        spaceContract = spaceContractAddr;
        landOperatorAddress = landOperatorAddr;
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
    }


    function tokenSpace(uint256 tokenId)
        external
        view
        onlyTokenCreated(tokenId)
        returns (uint256)
    {
        return tokenSpaces[tokenId];
    }
 
    function tokenLandCoordinates(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (int,int)
    {
        int x = tokenXCoordinates[tokenId];
        int y = tokenYCoordinates[tokenId];
        return (x,y); 
        
    } 

    function allCoordinates() 
        external 
        view 
        override 
        returns (int[] memory, int[] memory){
        uint tokenCount =  _tokenIdTracker.current();
        
        int[] memory retx = new int[](tokenCount);
        int[] memory rety = new int[](tokenCount);

        for (uint i = 0; i < tokenCount; i++) {
            retx[i] = tokenXCoordinates[i];
            rety[i] = tokenYCoordinates[i];
        }
        return (retx,rety);
    }
 

    function tokenURI(uint256 tokenId)
        public
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        string memory _tokenURI = _tokenURIs[tokenId];

        return _tokenURI;
    }

    function tokenMetadataURI(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        return _tokenMetadataURIs[tokenId];
    }

       function checkSpaceAttach(uint256 tokenId, address sender)
        external
        view
        override
        onlyTokenCreated(tokenId)
        onlyEmptyLand(tokenId)
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        require(
            owner == sender,
            "Space: owner of space is not the owner of land"
        );  
        return true;
    }


    function mint(LandData memory data, ILandExchange.BidShares memory bidShares)
        public
        override
        nonReentrant
    {
        _mintLand(msg.sender, data, bidShares);
    }

    function mintMultiple(LandData[] memory data, ILandExchange.BidShares[] memory bidShares)
        public
        override
        nonReentrant
    { 
    	  require(data.length > 0, "data must not be empty");
	     require(data.length <= 1000, "Length of data must be equal to or less than 10000");
	     require(data.length ==  bidShares.length, "Length of data and bidShares must match");

        for (uint i = 0; i < data.length; i++) {
           _mintLand(msg.sender, data[i], bidShares[i]);
        }
    } 

    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "Land: caller not approved address"
        );
        _approve(address(0), tokenId);
    }

  
    function listTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == landExchangeContract, "Land: only landExchange contract");
        previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

	function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }
 

    function setAsk(uint256 tokenId, ILandExchange.Ask memory ask)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        ILandExchange(landExchangeContract).setAsk(tokenId, ask);
    }

    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        ILandExchange(landExchangeContract).removeAsk(tokenId);
    }

    function setBid(uint256 tokenId, ILandExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(msg.sender == bid.bidder, "LandExchange: Bidder must be msg sender");
        ILandExchange(landExchangeContract).setBid(tokenId, bid, msg.sender);
    }

    function removeBid(uint256 tokenId)
        external
        override
        nonReentrant
        onlyTokenCreated(tokenId)
    {
        ILandExchange(landExchangeContract).removeBid(tokenId, msg.sender);
    }

    function acceptBid(uint256 tokenId, ILandExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        ILandExchange(landExchangeContract).acceptBid(tokenId, bid);
    }

    function burn(uint256 tokenId)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        address owner = ownerOf(tokenId);

        require(
            tokenCreators[tokenId] == owner,
            "Land: owner is not creator of land"
        );

        _burn(tokenId);
    }
 
 
    function updateTokenURI(uint256 tokenId, string calldata tokenURI)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithContentHash(tokenId)
        onlyValidURI(tokenURI)
    {
        _setTokenURI(tokenId, tokenURI);
        emit TokenURIUpdated(tokenId, msg.sender, tokenURI);
    }

    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithMetadataHash(tokenId)
        onlyValidURI(metadataURI)
    {
        _setTokenMetadataURI(tokenId, metadataURI);
        emit TokenMetadataURIUpdated(tokenId, msg.sender, metadataURI);
    } 

    function updateLandOperatorAddress(
        address newLandOperatorAddr 
    )
        external
        override
        nonReentrant 
    { 
        require(msg.sender == landOperatorAddress, "Land: only current land operator can update");
        _setLandOperatorAddress(newLandOperatorAddr);
        emit LandOperatorAddressUpdated(msg.sender, newLandOperatorAddr);
    }

    function updateTokenSpace(
        uint256 tokenId,
        uint256 spaceTokenId
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyValidSpace(msg.sender,spaceTokenId)
    {
        _setTokenSpace(tokenId, spaceTokenId);
        emit TokenSpaceUpdated(tokenId, msg.sender, spaceTokenId);
    }

    function removeTokenSpace(
        uint256 tokenId 
    )
        external
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyValidSpace(msg.sender,tokenId)
    {
        _removeTokenSpace(tokenId);
        emit TokenSpaceRemoved(tokenId, msg.sender);
    } 

    function _mintLand(
        address creator,
        LandData memory data,
        ILandExchange.BidShares memory bidShares
    ) internal onlyValidURI(data.tokenURI) onlyValidURI(data.metadataURI) {

        require(totalSupply() < maxSupply, 'Land: supply depleted');

        require(msg.sender == landOperatorAddress, "Land: only land operator can mint");

        require(-100 < data.xCoordinate && data.xCoordinate < 100 &&
                -100 < data.yCoordinate && data.yCoordinate < 100, 
                "Land: coordinates should be inside bounds");

        require(data.contentHash != 0, "Land: content hash must be non-zero");
        require(
            _contentHashes[data.contentHash] == false,
            "Land: a token has already been created with this content hash"
        );
        require(
            data.metadataHash != 0,
            "Land: metadata hash must be non-zero"
        );

        uint256 tokenId = _tokenIdTracker.current();

        _safeMint(creator, tokenId);
        _tokenIdTracker.increment();
        _setTokenContentHash(tokenId, data.contentHash);
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenMetadataURI(tokenId, data.metadataURI);
        _setTokenURI(tokenId, data.tokenURI);
        _setTokenLandCoordinates(tokenId, data.xCoordinate, data.yCoordinate);
        _creatorTokens[creator].add(tokenId);
        _contentHashes[data.contentHash] = true;

        tokenCreators[tokenId] = creator;
        previousTokenOwners[tokenId] = creator;
        ILandExchange(landExchangeContract).setBidShares(tokenId, bidShares);
    }
    function _setTokenContentHash(uint256 tokenId, bytes32 contentHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenContentHashes[tokenId] = contentHash;
    }

    function _setTokenMetadataHash(uint256 tokenId, bytes32 metadataHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenMetadataHashes[tokenId] = metadataHash;
    }

    function _setTokenMetadataURI(uint256 tokenId, string memory metadataURI)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenMetadataURIs[tokenId] = metadataURI;
    }


    function _setTokenSpace(uint256 tokenId, uint256 spaceTokenId)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenSpaces[tokenId] = spaceTokenId;
    }

    function _removeTokenSpace(uint256 tokenId)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        delete tokenSpaces[tokenId];
    }

    function _setLandOperatorAddress(address newLandOperatorAddr)
        internal
        virtual 
    {
        landOperatorAddress = newLandOperatorAddr; 
    }

    function _setTokenLandCoordinates(uint256 tokenId, int xCoordinate, int yCoordinate)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenXCoordinates[tokenId] = xCoordinate;
        tokenYCoordinates[tokenId] = yCoordinate;
    }


    function _burn(uint256 tokenId) internal override {
        string memory tokenURI = _tokenURIs[tokenId];

        super._burn(tokenId);

        if (bytes(tokenURI).length != 0) {
            _tokenURIs[tokenId] = tokenURI;
        }

        delete previousTokenOwners[tokenId];
    }
    
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        ILandExchange(landExchangeContract).removeAsk(tokenId);
        super._transfer(from, to, tokenId);
    }
 
}
