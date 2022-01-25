// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {Decimal} from "../Decimal.sol";
 
interface IAvatarExchange {
    struct Bid {
        uint256 amount; 
        address currency; 
        address bidder; 
        address recipient; 
        Decimal.D256 sellOnShare;
    }

    struct Ask { 
        uint256 amount; 
        address currency;
    }

    struct BidShares { 
        Decimal.D256 prevOwner; 
        Decimal.D256 creator; 
        Decimal.D256 owner;
    }

    event BidCreated(uint256 indexed tokenId, Bid bid);
    event BidRemoved(uint256 indexed tokenId, Bid bid);
    event BidFinalized(uint256 indexed tokenId, Bid bid);
    event AskCreated(uint256 indexed tokenId, Ask ask);
    event AskRemoved(uint256 indexed tokenId, Ask ask);
    event BidShareUpdated(uint256 indexed tokenId, BidShares bidShares);

    function bidForTokenBidder(uint256 tokenId, address bidder)
        external
        view
        returns (Bid memory);

    function currentAskForToken(uint256 tokenId)
        external
        view
        returns (Ask memory);

    function bidSharesForToken(uint256 tokenId)
        external
        view
        returns (BidShares memory);

    function isValidBid(uint256 tokenId, uint256 bidAmount)
        external
        view
        returns (bool);

    function isValidBidShares(BidShares calldata bidShares)
        external
        pure
        returns (bool);

    function splitShare(Decimal.D256 calldata sharePercentage, uint256 amount)
        external
        pure
        returns (uint256);

    function configure(address avatarContractAddress) external;

    function setBidShares(uint256 tokenId, BidShares calldata bidShares)
        external;

    function setAsk(uint256 tokenId, Ask calldata ask) external;

    function removeAsk(uint256 tokenId) external;

    function setBid(
        uint256 tokenId,
        Bid calldata bid,
        address spender
    ) external;

    function removeBid(uint256 tokenId, address bidder) external;

    function acceptBid(uint256 tokenId, Bid calldata expectedBid) external;
}
