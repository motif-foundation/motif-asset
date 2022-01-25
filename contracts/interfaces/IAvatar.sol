// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IAvatarExchange} from "./IAvatarExchange.sol";
 
interface IAvatar {
    struct AvatarData { 
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

    function mint(AvatarData calldata data, IAvatarExchange.BidShares calldata bidShares)
        external;

    function listTransfer(uint256 tokenId, address recipient) external; 
    function setAsk(uint256 tokenId, IAvatarExchange.Ask calldata ask) external; 
    function removeAsk(uint256 tokenId) external; 
    function setBid(uint256 tokenId, IAvatarExchange.Bid calldata bid) external; 
    function removeBid(uint256 tokenId) external; 
    function acceptBid(uint256 tokenId, IAvatarExchange.Bid calldata bid) external; 
    function revokeApproval(uint256 tokenId) external; 
    function updateTokenURI(uint256 tokenId, string calldata tokenURI) external;

    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    ) external;
  
}
