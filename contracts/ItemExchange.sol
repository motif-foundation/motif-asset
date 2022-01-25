// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Decimal} from "./Decimal.sol";
import {Item} from "./Item.sol";
import {IItemExchange} from "./interfaces/IItemExchange.sol";
 
contract ItemExchange is IItemExchange {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
 
    address public itemContract;
 
    address private _owner; 
    mapping(uint256 => mapping(address => Bid)) private _tokenBidders; 
    mapping(uint256 => BidShares) private _bidShares; 
    mapping(uint256 => Ask) private _tokenAsks;
 
    modifier onlyItemCaller() {
        require(itemContract == msg.sender, "ItemExchange: Only item contract");
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
            "ItemExchange: Invalid bid shares for token"
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
 
    function configure(address itemContractAddress) external override {
        require(msg.sender == _owner, "ItemExchange: Only owner");
        require(itemContract == address(0), "ItemExchange: Already configured");
        require(
            itemContractAddress != address(0),
            "ItemExchange: cannot set item contract as zero address"
        );

        itemContract = itemContractAddress;
    }
 
    function setBidShares(uint256 tokenId, BidShares memory bidShares)
        public
        override
        onlyItemCaller
    {
        require(
            isValidBidShares(bidShares),
            "ItemExchange: Invalid bid shares, must sum to 100"
        );
        _bidShares[tokenId] = bidShares;
        emit BidShareUpdated(tokenId, bidShares);
    }
 
    function setAsk(uint256 tokenId, Ask memory ask)
        public
        override
        onlyItemCaller
    {
        require(
            isValidBid(tokenId, ask.amount),
            "ItemExchange: Ask invalid for share splitting"
        );

        _tokenAsks[tokenId] = ask;
        emit AskCreated(tokenId, ask);
    }
 
    function removeAsk(uint256 tokenId) external override onlyItemCaller {
        emit AskRemoved(tokenId, _tokenAsks[tokenId]);
        delete _tokenAsks[tokenId];
    }
 
    function setBid(
        uint256 tokenId,
        Bid memory bid,
        address spender
    ) public override onlyItemCaller {
        BidShares memory bidShares = _bidShares[tokenId];
        require(
            bidShares.creator.value.add(bid.sellOnShare.value) <=
                uint256(100).mul(Decimal.BASE),
            "ItemExchange: Sell on fee invalid for share splitting"
        );
        require(bid.bidder != address(0), "ItemExchange: bidder cannot be 0 address");
        require(bid.amount != 0, "ItemExchange: cannot bid amount of 0");
        require(
            bid.currency != address(0),
            "ItemExchange: bid currency cannot be 0 address"
        );
        require(
            bid.recipient != address(0),
            "ItemExchange: bid recipient cannot be 0 address"
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
        onlyItemCaller
    {
        Bid storage bid = _tokenBidders[tokenId][bidder];
        uint256 bidAmount = bid.amount;
        address bidCurrency = bid.currency; 
        require(bid.amount > 0, "ItemExchange: cannot remove bid amount of 0"); 
        IERC20 token = IERC20(bidCurrency); 
        emit BidRemoved(tokenId, bid);
        delete _tokenBidders[tokenId][bidder];
        token.safeTransfer(bidder, bidAmount);
    }
 
    function acceptBid(uint256 tokenId, Bid calldata expectedBid)
        external
        override
        onlyItemCaller
    {
        Bid memory bid = _tokenBidders[tokenId][expectedBid.bidder];
        require(bid.amount > 0, "ItemExchange: cannot accept bid of 0");
        require(
            bid.amount == expectedBid.amount &&
                bid.currency == expectedBid.currency &&
                bid.sellOnShare.value == expectedBid.sellOnShare.value &&
                bid.recipient == expectedBid.recipient,
            "ItemExchange: Unexpected bid found."
        );
        require(
            isValidBid(tokenId, bid.amount),
            "ItemExchange: Bid invalid for share splitting"
        ); 
        _finalizeNFTTransfer(tokenId, bid.bidder);
    }
 
    function _finalizeNFTTransfer(uint256 tokenId, address bidder) private {
        Bid memory bid = _tokenBidders[tokenId][bidder];
        BidShares storage bidShares = _bidShares[tokenId]; 
        IERC20 token = IERC20(bid.currency); 
        token.safeTransfer(
            IERC721(itemContract).ownerOf(tokenId),
            splitShare(bidShares.owner, bid.amount)
        );
        token.safeTransfer(
            Item(itemContract).tokenCreators(tokenId),
            splitShare(bidShares.creator, bid.amount)
        ); 
        token.safeTransfer(
            Item(itemContract).previousTokenOwners(tokenId),
            splitShare(bidShares.prevOwner, bid.amount)
        ); 
        Item(itemContract).listTransfer(tokenId, bid.recipient); 

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
