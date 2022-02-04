pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {ERC721Burnable} from "./ERC721Burnable.sol";
import {ERC721} from "./ERC721.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol"; 
import {Decimal} from "./Decimal.sol";
import {IAvatarExchange} from "./interfaces/IAvatarExchange.sol";
import "./interfaces/IAvatar.sol";
 
contract Avatar is IAvatar, ERC721Burnable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    address public avatarExchangeContract; 
    mapping(uint256 => address) public previousTokenOwners; 
    mapping(uint256 => address) public tokenCreators; 
    mapping(address => EnumerableSet.UintSet) private _creatorTokens; 
    mapping(uint256 => bytes32) public tokenContentHashes; 
    mapping(uint256 => bytes32) public tokenMetadataHashes; 
    mapping(uint256 => string) private _tokenMetadataURIs; 
    mapping(uint256 => bool) private _tokenDefaults; 
    mapping(bytes32 => bool) private _contentHashes; 

    uint256 public maxSupply = 100000;//100K Avatars

 
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x96905846;  
 
    Counters.Counter private _tokenIdTracker;
 
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Avatar: nonexistent token");
        _;
    }
 
    modifier onlyTokenWithContentHash(uint256 tokenId) {
        require(
            tokenContentHashes[tokenId] != 0,
            "Avatar: token does not have hash of created content"
        );
        _;
    }

 
    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "Avatar: token does not have hash of its metadata"
        );
        _;
    }

 
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Avatar: Only approved or owner"
        );
        _;
    }
 
    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            _tokenIdTracker.current() > tokenId,
            "Avatar: token with that id does not exist"
        );
        _;
    }
 
    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "Avatar: specified uri must be non-empty"
        );
        _;
    }
 
    constructor(address avatarExchangeContractAddr) 
        public ERC721("Motif Avatar","AVATAR") { 
        avatarExchangeContract = avatarExchangeContractAddr;
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

    function tokenDefault(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (bool)
    {
        return _tokenDefaults[tokenId];
    }
 
    function mint(AvatarData memory data, IAvatarExchange.BidShares memory bidShares)
        public
        override
        nonReentrant
    {
        _mintAvatar(msg.sender, data, bidShares);
    }
 
 
    function listTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == avatarExchangeContract, "Avatar: only avatarExchange contract");
        previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

 
    function setAsk(uint256 tokenId, IAvatarExchange.Ask memory ask)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IAvatarExchange(avatarExchangeContract).setAsk(tokenId, ask);
    }
 
    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IAvatarExchange(avatarExchangeContract).removeAsk(tokenId);
    }
 
    function setBid(uint256 tokenId, IAvatarExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(msg.sender == bid.bidder, "AvatarExchange: Bidder must be msg sender");
        IAvatarExchange(avatarExchangeContract).setBid(tokenId, bid, msg.sender);
    }
 
    function removeBid(uint256 tokenId)
        external
        override
        nonReentrant
        onlyTokenCreated(tokenId)
    {
        IAvatarExchange(avatarExchangeContract).removeBid(tokenId, msg.sender);
    }
 
    function acceptBid(uint256 tokenId, IAvatarExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IAvatarExchange(avatarExchangeContract).acceptBid(tokenId, bid);
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
            "Avatar: owner is not creator of avatar"
        ); 
        _burn(tokenId);
    }

    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "Avatar: caller not approved address"
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

    function updateTokenDefault(
        uint256 tokenId,
        bool isDefault
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithMetadataHash(tokenId) 
    {
        _setTokenDefault(tokenId, isDefault);
        emit TokenDefaultUpdated(tokenId, msg.sender, isDefault);
    }
 
 
    function _mintAvatar(
        address creator,
        AvatarData memory data,
        IAvatarExchange.BidShares memory bidShares
    ) internal onlyValidURI(data.tokenURI) onlyValidURI(data.metadataURI) {

    	  require(totalSupply() < maxSupply, 'Land: supply depleted');

        require(data.contentHash != 0, "Avatar: content hash must be non-zero");
        
        require(
            _contentHashes[data.contentHash] == false,
            "Avatar: a token has already been created with this content hash"
        );
        
        require(
            data.metadataHash != 0,
            "Avatar: metadata hash must be non-zero"
        );

        uint256 tokenId = _tokenIdTracker.current();

        _safeMint(creator, tokenId);
        _tokenIdTracker.increment();
        _setTokenContentHash(tokenId, data.contentHash);
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenMetadataURI(tokenId, data.metadataURI);
        _setTokenDefault(tokenId, data.isDefault);
        _setTokenURI(tokenId, data.tokenURI);
        _creatorTokens[creator].add(tokenId);
        _contentHashes[data.contentHash] = true;

        tokenCreators[tokenId] = creator;
        previousTokenOwners[tokenId] = creator;
        IAvatarExchange(avatarExchangeContract).setBidShares(tokenId, bidShares);
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

    function _setTokenDefault(uint256 tokenId, bool isDefault)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenDefaults[tokenId] = isDefault;
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
        IAvatarExchange(avatarExchangeContract).removeAsk(tokenId);

        super._transfer(from, to, tokenId);
    }
  
}
