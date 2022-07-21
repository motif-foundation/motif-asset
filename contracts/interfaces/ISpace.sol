// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {ISpaceExchange} from "./ISpaceExchange.sol";
 
interface ISpace {
    struct SpaceData { 
        string tokenURI; 
        string metadataURI; 
        bytes32 contentHash; 
        bytes32 metadataHash; 
        uint256[] lands; 
        string pin;
    }

    event TokenURIUpdated(uint256 indexed _tokenId, address owner, string _uri); 
    event TokenMetadataURIUpdated(
        uint256 indexed _tokenId,
        address owner,
        string _uri
    );

    event TokenLandsUpdated(uint256 indexed _tokenId, address owner, uint256[] lands);

    function tokenMetadataURI(uint256 tokenId)
        external
        view
        returns (string memory);

    function tokenPin(uint256 tokenId)
        external
        view
        returns (string memory);

    function tokenLandDetails(uint256 tokenId)
     external
     view
     returns (uint256[] memory);
     
    function checkLandAttach(uint256 tokenId, address sender) external view returns (bool);

    function mint(SpaceData calldata data, ISpaceExchange.BidShares calldata bidShares)
        external;
 
    function listTransfer(uint256 tokenId, address recipient) external; 
    function setAsk(uint256 tokenId, ISpaceExchange.Ask calldata ask) external; 
    function removeAsk(uint256 tokenId) external; 
    function setBid(uint256 tokenId, ISpaceExchange.Bid calldata bid) external; 
    function removeBid(uint256 tokenId) external; 
    function acceptBid(uint256 tokenId, ISpaceExchange.Bid calldata bid) external; 
    function revokeApproval(uint256 tokenId) external; 
    function updateTokenURI(uint256 tokenId, string calldata tokenURI) external; 
    function updateTokenLands(uint256 tokenId, uint256[] calldata lands) external;

    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    ) external;
  
}
