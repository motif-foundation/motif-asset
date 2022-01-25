pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {ERC721Burnable} from "./ERC721Burnable.sol";
import {ERC721} from "./ERC721.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Decimal} from "./Decimal.sol";
import {ISpaceExchange} from "./interfaces/ISpaceExchange.sol";
import "./interfaces/ISpace.sol";
	import {ILand} from "./interfaces/ILand.sol";
import "./interfaces/ILand.sol"; 

contract Space is ISpace, ERC721Burnable, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
 
    address public spaceExchangeContract;
  	address public landContract;
    bool isInitialized = false; 
 
    mapping(uint256 => address) public previousTokenOwners; 
    mapping(uint256 => address) public tokenCreators; 
    mapping(address => EnumerableSet.UintSet) private _creatorTokens; 
    mapping(uint256 => bytes32) public tokenContentHashes; 
    mapping(uint256 => bytes32) public tokenMetadataHashes; 
    mapping(uint256 => address) public tokenContractAddresses;  
    mapping(uint256 => string) private _tokenMetadataURIs; 
    mapping(bytes32 => bool) private _contentHashes;  
	 mapping(uint256 => bool) public tokenIsPublicRecord;  
    mapping(uint256 => uint256[]) public tokenLands;  

    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0xa990b5e5;

    Counters.Counter private _tokenIdTracker;

    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Space: nonexistent token");
        _;
    }

    modifier onlyTokenWithContentHash(uint256 tokenId) {
        require(
            tokenContentHashes[tokenId] != 0,
            "Space: token does not have hash of created content"
        );
        _;
    }

    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "Space: token does not have hash of its metadata"
        );
        _;
    }

    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Space: Only approved or owner"
        );
        _;
    }

    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            _tokenIdTracker.current() > tokenId,
            "Space: token with that id does not exist"
        );
        _;
    }

    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "Space: specified uri must be non-empty"
        );
        _;
    }

    constructor(address spaceExchangeContractAddr) 
        public ERC721("Motif Space","SPACE") {
        spaceExchangeContract = spaceExchangeContractAddr;
        maxSupply = maxSupplyAmount;
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
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

	function checkLandAttach(uint256 tokenId, address sender)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        require(
            owner == sender,
            "Space: owner of space is not the owner of land"
        );  
        return true;
    }

    function mint(SpaceData memory data, ISpaceExchange.BidShares memory bidShares)
        public
        override
        nonReentrant
    {
        _mintSpace(msg.sender, data, bidShares);
    }
 

    function listTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == spaceExchangeContract, "Space: only spaceExchange contract");
        previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

    function setAsk(uint256 tokenId, ISpaceExchange.Ask memory ask)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        ISpaceExchange(spaceExchangeContract).setAsk(tokenId, ask);
    }

    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        ISpaceExchange(spaceExchangeContract).removeAsk(tokenId);
    }

    function setBid(uint256 tokenId, ISpaceExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(msg.sender == bid.bidder, "SpaceExchange: Bidder must be msg sender");
        ISpaceExchange(spaceExchangeContract).setBid(tokenId, bid, msg.sender);
    }

    function removeBid(uint256 tokenId)
        external
        override
        nonReentrant
        onlyTokenCreated(tokenId)
    {
        ISpaceExchange(spaceExchangeContract).removeBid(tokenId, msg.sender);
    }

    function acceptBid(uint256 tokenId, ISpaceExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        ISpaceExchange(spaceExchangeContract).acceptBid(tokenId, bid);
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
            "Space: owner is not creator of space"
        );

        _burn(tokenId);
    }
 
    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "Space: caller not approved address"
        );
        _approve(address(0), tokenId);
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

 function updateTokenLands(
        uint256 tokenId,
        uint256[] calldata lands
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithMetadataHash(tokenId) 
    {
        for (uint i = 0; i < lands.length; i++) { 
            bool landAttachable =  ILand(landContract).checkSpaceAttach(lands[i],msg.sender);
            require(landAttachable == true,
                "Land: sender doesn't own land or land occupied"
            ); 
        }
        _setTokenLands(tokenId, lands);
        emit TokenLandsUpdated(tokenId, msg.sender, lands);
    }

 
  function initialize(address _landContract) public {
        require(!isInitialized, 'Space: contract is already initialized!');
        isInitialized = true;
        landContract = _landContract;
    }
 
    function _mintSpace(
        address creator,
        SpaceData memory data,
        ISpaceExchange.BidShares memory bidShares
    ) internal 
        onlyValidURI(data.tokenURI) 
        onlyValidURI(data.metadataURI) { 

        require(data.contentHash != 0, 
            "Space: content hash must be non-zero");

        require(
            _contentHashes[data.contentHash] == false,
            "Space: a token has already been created with this content hash"
        );

        require(
            data.metadataHash != 0,
            "Space: metadata hash must be non-zero"
        );

        require((data.isPublic == true || data.isPublic == false), 
            "Space: space access cannot be empty");


        uint256 tokenId = _tokenIdTracker.current();

        if(data.isPublic) {
            require(data.lands.length > 0, "Space: public space must have land"); 
            for (uint i = 0; i < data.lands.length; i++) { 
                bool landAttachable =  ILand(landContract).checkSpaceAttach(data.lands[i],msg.sender);
                require(landAttachable == true,
                    "Land: sender doesn't own land or land occupied"
                ); 
            }
            _safeMint(creator, tokenId);
            _setTokenLands(tokenId, data.lands);
        } else {
            _safeMint(creator, tokenId);
        }

        _tokenIdTracker.increment();
        _setTokenContentHash(tokenId, data.contentHash);
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenMetadataURI(tokenId, data.metadataURI);
        _setTokenURI(tokenId, data.tokenURI);
        _setTokenIsPublic(tokenId, data.isPublic); 
        _creatorTokens[creator].add(tokenId);
        _contentHashes[data.contentHash] = true; 
        tokenCreators[tokenId] = creator;
        previousTokenOwners[tokenId] = creator;
        ISpaceExchange(spaceExchangeContract).setBidShares(tokenId, bidShares);
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

    function _setTokenContract(uint256 tokenId, address tokenContract)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenContractAddresses[tokenId] = tokenContract;
    }



    function _setTokenLands(uint256 tokenId, uint256[] memory lands)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenLands[tokenId] = lands;
    }

    function _setTokenMetadataURI(uint256 tokenId, string memory metadataURI)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenMetadataURIs[tokenId] = metadataURI;
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
        ISpaceExchange(spaceExchangeContract).removeAsk(tokenId);
        super._transfer(from, to, tokenId);
    }
 
}