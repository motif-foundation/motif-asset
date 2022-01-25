pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Decimal} from "./Decimal.sol";
import {Space} from "./Space.sol";
import {ISpaceExchange} from "./interfaces/ISpaceExchange.sol";
 
contract SpaceExchange is ISpaceExchange {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
 
    address public spaceContract;
 
    address private _owner; 
    mapping(uint256 => mapping(address => Bid)) private _tokenBidders; 
    mapping(uint256 => BidShares) private _bidShares; 
    mapping(uint256 => Ask) private _tokenAsks;
 
    modifier onlySpaceCaller() {
        require(spaceContract == msg.sender, "SpaceExchange: Only space contract");
        _;
    }
 
    function bidForTokenBidder(uint256 tokenId, address bidder)
        external
        view
        override
        returns (Bid memory)
    {
        return _tokenBidders[tokenId][bidder];
    }

    function currentAskForToken(uint256 tokenId)
        external
        view
        override
        returns (Ask memory)
    {
        return _tokenAsks[tokenId];
    }

    function bidSharesForToken(uint256 tokenId)
        public
        view
        override
        returns (BidShares memory)
    {
        return _bidShares[tokenId];
    }
 
    function isValidBid(uint256 tokenId, uint256 bidAmount)
        public
        view
        override
        returns (bool)
    {
        BidShares memory bidShares = bidSharesForToken(tokenId);
        require(
            isValidBidShares(bidShares),
            "SpaceExchange: Invalid bid shares for token"
        );
        return
            bidAmount != 0 &&
            (bidAmount ==
                splitShare(bidShares.creator, bidAmount)
                    .add(splitShare(bidShares.prevOwner, bidAmount))
                    .add(splitShare(bidShares.owner, bidAmount)));
    }
 
    function isValidBidShares(BidShares memory bidShares)
        public
        pure
        override
        returns (bool)
    {
        return
            bidShares.creator.value.add(bidShares.owner.value).add(
                bidShares.prevOwner.value
            ) == uint256(100).mul(Decimal.BASE);
    }
 
    function splitShare(Decimal.D256 memory sharePercentage, uint256 amount)
        public
        pure
        override
        returns (uint256)
    {
        return Decimal.mul(amount, sharePercentage).div(100);
    }
 
    constructor() public {
        _owner = msg.sender;
    }
 
    function configure(address spaceContractAddress) external override {
        require(msg.sender == _owner, "SpaceExchange: Only owner");
        require(spaceContract == address(0), "SpaceExchange: Already configured");
        require(
            spaceContractAddress != address(0),
            "SpaceExchange: cannot set space contract as zero address"
        );

        spaceContract = spaceContractAddress;
    }
 
    function setBidShares(uint256 tokenId, BidShares memory bidShares)
        public
        override
        onlySpaceCaller
    {
        require(
            isValidBidShares(bidShares),
            "SpaceExchange: Invalid bid shares, must sum to 100"
        );
        _bidShares[tokenId] = bidShares;
        emit BidShareUpdated(tokenId, bidShares);
    }
 
    function setAsk(uint256 tokenId, Ask memory ask)
        public
        override
        onlySpaceCaller
    {
        require(
            isValidBid(tokenId, ask.amount),
            "SpaceExchange: Ask invalid for share splitting"
        );

        _tokenAsks[tokenId] = ask;
        emit AskCreated(tokenId, ask);
    }
 
    function removeAsk(uint256 tokenId) external override onlySpaceCaller {
        emit AskRemoved(tokenId, _tokenAsks[tokenId]);
        delete _tokenAsks[tokenId];
    }
 
    function setBid(
        uint256 tokenId,
        Bid memory bid,
        address spender
    ) public override onlySpaceCaller {
        BidShares memory bidShares = _bidShares[tokenId];
        require(
            bidShares.creator.value.add(bid.sellOnShare.value) <=
                uint256(100).mul(Decimal.BASE),
            "SpaceExchange: Sell on fee invalid for share splitting"
        );
        require(bid.bidder != address(0), "SpaceExchange: bidder cannot be 0 address");
        require(bid.amount != 0, "SpaceExchange: cannot bid amount of 0");
        require(
            bid.currency != address(0),
            "SpaceExchange: bid currency cannot be 0 address"
        );
        require(
            bid.recipient != address(0),
            "SpaceExchange: bid recipient cannot be 0 address"
        ); 
        Bid storage existingBid = _tokenBidders[tokenId][bid.bidder];  
        if (existingBid.amount > 0) {
            removeBid(tokenId, bid.bidder);
        } 
        IERC20 token = IERC20(bid.currency); 
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(spender, address(this), bid.amount);
        uint256 afterBalance = token.balanceOf(address(this));
        _tokenBidders[tokenId][bid.bidder] = Bid(
            afterBalance.sub(beforeBalance),
            bid.currency,
            bid.bidder,
            bid.recipient,
            bid.sellOnShare
        );
        emit BidCreated(tokenId, bid);  
        if (
            _tokenAsks[tokenId].currency != address(0) &&
            bid.currency == _tokenAsks[tokenId].currency &&
            bid.amount >= _tokenAsks[tokenId].amount
        ) {
            _finalizeNFTTransfer(tokenId, bid.bidder);
        }
    }
 
    function removeBid(uint256 tokenId, address bidder)
        public
        override
        onlySpaceCaller
    {
        Bid storage bid = _tokenBidders[tokenId][bidder];
        uint256 bidAmount = bid.amount;
        address bidCurrency = bid.currency; 
        require(bid.amount > 0, "SpaceExchange: cannot remove bid amount of 0"); 
        IERC20 token = IERC20(bidCurrency); 
        emit BidRemoved(tokenId, bid);
        delete _tokenBidders[tokenId][bidder];
        token.safeTransfer(bidder, bidAmount);
    }
 
    function acceptBid(uint256 tokenId, Bid calldata expectedBid)
        external
        override
        onlySpaceCaller
    {
        Bid memory bid = _tokenBidders[tokenId][expectedBid.bidder];
        require(bid.amount > 0, "SpaceExchange: cannot accept bid of 0");
        require(
            bid.amount == expectedBid.amount &&
                bid.currency == expectedBid.currency &&
                bid.sellOnShare.value == expectedBid.sellOnShare.value &&
                bid.recipient == expectedBid.recipient,
            "SpaceExchange: Unexpected bid found."
        );
        require(
            isValidBid(tokenId, bid.amount),
            "SpaceExchange: Bid invalid for share splitting"
        ); 
        _finalizeNFTTransfer(tokenId, bid.bidder);
    }
 
    function _finalizeNFTTransfer(uint256 tokenId, address bidder) private {
        Bid memory bid = _tokenBidders[tokenId][bidder];
        BidShares storage bidShares = _bidShares[tokenId]; 
        IERC20 token = IERC20(bid.currency); 
        token.safeTransfer(
            IERC721(spaceContract).ownerOf(tokenId),
            splitShare(bidShares.owner, bid.amount)
        );
        token.safeTransfer(
            Space(spaceContract).tokenCreators(tokenId),
            splitShare(bidShares.creator, bid.amount)
        ); 
        token.safeTransfer(
            Space(spaceContract).previousTokenOwners(tokenId),
            splitShare(bidShares.prevOwner, bid.amount)
        ); 
        Space(spaceContract).listTransfer(tokenId, bid.recipient); 

        bidShares.owner = Decimal.D256(
            uint256(100)
                .mul(Decimal.BASE)
                .sub(_bidShares[tokenId].creator.value)
                .sub(bid.sellOnShare.value)
        ); 
        bidShares.prevOwner = bid.sellOnShare; 
        delete _tokenBidders[tokenId][bidder]; 
        emit BidShareUpdated(tokenId, bidShares);
        emit BidFinalized(tokenId, bid);
    }
}
