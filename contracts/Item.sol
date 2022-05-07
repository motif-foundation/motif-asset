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
import {IItemExchange} from "./interfaces/IItemExchange.sol";
import "./interfaces/IItem.sol";

contract Item is IItem, ERC721Burnable, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
 
    address public itemExchangeContract;
    string public itemIdentifier;
    uint256 public maxSupply; 
 
    mapping(uint256 => address) public previousTokenOwners; 
    mapping(uint256 => address) public tokenCreators; 
    mapping(address => EnumerableSet.UintSet) private _creatorTokens; 
    mapping(uint256 => bytes32) public tokenContentHashes; 
    mapping(uint256 => bytes32) public tokenMetadataHashes; 
    mapping(uint256 => address) public tokenContractAddresses;  
    mapping(uint256 => string) private _tokenMetadataURIs; 
    mapping(bytes32 => bool) private _contentHashes; 
    mapping(address => mapping(uint256 => uint256)) public permitNonces;
    mapping(address => uint256) public mintWithSigNonces;

    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0xc904b9c6; 
    bytes32 public constant PERMIT_TYPEHASH = 0xadacbbfdfd82dabfa913ef6727df5bc21f8699a2969db41d446fee646fc64b9e; 
    bytes32 public constant MINT_WITH_SIG_TYPEHASH =  0x93088eb7747c9bc240a8edd9669cbcc6663249f8e821916b3305e54cca2017f7;

    Counters.Counter private _tokenIdTracker;

    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Item: nonexistent token");
        _;
    }

    modifier onlyTokenWithContentHash(uint256 tokenId) {
        require(
            tokenContentHashes[tokenId] != 0,
            "Item: token does not have hash of created content"
        );
        _;
    }

    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "Item: token does not have hash of its metadata"
        );
        _;
    }

    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Item: Only approved or owner"
        );
        _;
    }

    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            _tokenIdTracker.current() > tokenId,
            "Item: token with that id does not exist"
        );
        _;
    }

    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "Item: specified uri must be non-empty"
        );
        _;
    }

    constructor(address itemExchangeContractAddr, string memory name_,string memory symbol_, uint256 maxSupplyAmount, string memory itemIdentifierString) 
        public ERC721(name_,symbol_) {
        itemExchangeContract = itemExchangeContractAddr;
        maxSupply = maxSupplyAmount;
        itemIdentifier = itemIdentifierString;
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

    function getItemIdentifier()
        external
        view
        override
        returns (string memory)
    {
        return itemIdentifier;
    }
 
    function mint(ItemData memory data, IItemExchange.BidShares memory bidShares)
        public
        override
        nonReentrant
    {
        _mintForCreator(msg.sender, data, bidShares);
    }

    function mintMultiple(ItemData[] memory data, IItemExchange.BidShares[] memory bidShares)
        public
        override
        nonReentrant
    { 
    	  require(data.length > 0, "data must not be empty");
	     require(data.length <= 10000, "Length of data must be equal to or less than 10000");
	     require(data.length ==  bidShares.length, "Length of data and bidShares must match");

        for (uint i = 0; i < data.length; i++) {
           _mintForCreator(msg.sender, data[i], bidShares[i]);
        }
    }  

    function mintForCreatorWithoutSig(address creator, ItemData memory data, IItemExchange.BidShares memory bidShares)
        public
        override
        nonReentrant
    {
        _mintForCreator(creator, data, bidShares);
    }

  function mintForCreatorWithSig(
        address creator,
        ItemData memory data,
        IItemExchange.BidShares memory bidShares,
        EIP712Signature memory sig
    ) public override nonReentrant {
        require(
            sig.deadline == 0 || sig.deadline >= block.timestamp,
            "Item: mintWithSig expired"
        );

        bytes32 domainSeparator = _calculateDomainSeparator();

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            MINT_WITH_SIG_TYPEHASH,
                            data.contentHash,
                            data.metadataHash,
                            bidShares.creator.value,
                            mintWithSigNonces[creator]++,
                            sig.deadline
                        )
                    )
                )
            );

        address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

        require(
            recoveredAddress != address(0) && creator == recoveredAddress,
            "Item: Signature invalid"
        );

        _mintForCreator(recoveredAddress, data, bidShares);
    }
 

    function listTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == itemExchangeContract, "Item: only itemExchange contract");
        previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

    function setAsk(uint256 tokenId, IItemExchange.Ask memory ask)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IItemExchange(itemExchangeContract).setAsk(tokenId, ask);
    }

    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IItemExchange(itemExchangeContract).removeAsk(tokenId);
    }

    function setBid(uint256 tokenId, IItemExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(msg.sender == bid.bidder, "ItemExchange: Bidder must be msg sender");
        IItemExchange(itemExchangeContract).setBid(tokenId, bid, msg.sender);
    }

    function removeBid(uint256 tokenId)
        external
        override
        nonReentrant
        onlyTokenCreated(tokenId)
    {
        IItemExchange(itemExchangeContract).removeBid(tokenId, msg.sender);
    }

    function acceptBid(uint256 tokenId, IItemExchange.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IItemExchange(itemExchangeContract).acceptBid(tokenId, bid);
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
            "Item: owner is not creator of item"
        );

        _burn(tokenId);
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
 

    function transferContractOwnership(address newOwner)
        public 
        nonReentrant onlyOwner
    {
        _transferOwnership(newOwner);
    }

    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "Item: caller not approved address"
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

    function permit(
        address spender,
        uint256 tokenId,
        EIP712Signature memory sig
    ) public override nonReentrant onlyExistingToken(tokenId) {
        require(
            sig.deadline == 0 || sig.deadline >= block.timestamp,
            "Item: Permit expired"
        );
        require(spender != address(0), "Item: spender cannot be 0x0");
        bytes32 domainSeparator = _calculateDomainSeparator();

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            spender,
                            tokenId,
                            permitNonces[ownerOf(tokenId)][tokenId]++,
                            sig.deadline
                        )
                    )
                )
            );

        address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

        require(
            recoveredAddress != address(0) &&
                ownerOf(tokenId) == recoveredAddress,
            "Item: Signature invalid"
        );

        _approve(spender, tokenId);
    }

    function _mintForCreator(
        address creator,
        ItemData memory data,
        IItemExchange.BidShares memory bidShares
    ) internal onlyValidURI(data.tokenURI) onlyValidURI(data.metadataURI) {
    	  
    	  require(totalSupply() < maxSupply, 'Item: supply depleted');

        require(data.contentHash != 0, "Item: content hash must be non-zero");
        require(
            _contentHashes[data.contentHash] == false,
            "Item: a token has already been created with this content hash"
        );
        require(
            data.metadataHash != 0,
            "Item: metadata hash must be non-zero"
        );

        uint256 tokenId = _tokenIdTracker.current();

        _safeMint(creator, tokenId);
        _tokenIdTracker.increment();
        _setTokenContentHash(tokenId, data.contentHash);
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenContract(tokenId, address(this));
        _setTokenMetadataURI(tokenId, data.metadataURI);
        _setTokenURI(tokenId, data.tokenURI);
        _creatorTokens[creator].add(tokenId);
        _contentHashes[data.contentHash] = true; 
        tokenCreators[tokenId] = creator;
        previousTokenOwners[tokenId] = creator;
        IItemExchange(itemExchangeContract).setBidShares(tokenId, bidShares);
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

  	 function _transferOwnership(address newOwner) internal  { 
        super.transferOwnership(newOwner); 
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        IItemExchange(itemExchangeContract).removeAsk(tokenId);
        super._transfer(from, to, tokenId);
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        uint256 chainID;
        assembly {
            chainID := chainid()
        }

        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Motif")),
                    keccak256(bytes("1")),
                    chainID,
                    address(this)
                )
            );
    }
}
