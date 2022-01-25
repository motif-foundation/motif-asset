// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IItemExchange} from "./IItemExchange.sol";
 
interface IItem {
    struct EIP712Signature {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct ItemData { 
        string tokenURI; 
        string metadataURI; 
        bytes32 contentHash; 
        bytes32 metadataHash;
    }

    event TokenURIUpdated(uint256 indexed _tokenId, address owner, string _uri);
    event TokenMetadataURIUpdated(
        uint256 indexed _tokenId,
        address owner,
        string _uri
    );

    function tokenMetadataURI(uint256 tokenId)
        external
        view
        returns (string memory);

    function mint(ItemData calldata data, IItemExchange.BidShares calldata bidShares)
        external;

    function mintForCreatorWithoutSig(address creator, ItemData calldata data, IItemExchange.BidShares calldata bidShares)
        external; 

    function mintForCreatorWithSig(
        address creator,
        ItemData calldata data,
        IItemExchange.BidShares calldata bidShares,
        EIP712Signature calldata sig
    ) external;
 
    function listTransfer(uint256 tokenId, address recipient) external; 
    function setAsk(uint256 tokenId, IItemExchange.Ask calldata ask) external; 
    function removeAsk(uint256 tokenId) external; 
    function setBid(uint256 tokenId, IItemExchange.Bid calldata bid) external; 
    function removeBid(uint256 tokenId) external; 
    function acceptBid(uint256 tokenId, IItemExchange.Bid calldata bid) external; 
    function revokeApproval(uint256 tokenId) external; 
    function updateTokenURI(uint256 tokenId, string calldata tokenURI) external;

    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    ) external;
 
    function permit(
        address spender,
        uint256 tokenId,
        EIP712Signature calldata sig
    ) external;
}
