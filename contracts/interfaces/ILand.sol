// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {ILandExchange} from "./ILandExchange.sol";
 
interface ILand {
    struct LandData { 
        string tokenURI; 
        string metadataURI; 
        bytes32 contentHash; 
        bytes32 metadataHash;
        int xCoordinate;
        int yCoordinate;
    }

    event TokenURIUpdated(uint256 indexed _tokenId, address owner, string _uri);

    event TokenMetadataURIUpdated(
        uint256 indexed _tokenId,
        address owner,
        string _uri
    );

    event LandOperatorAddressUpdated(
        address owner,
        address _newLandOperatorAddress
    );

    event TokenSpaceUpdated(
        uint256 indexed _tokenId,
        address owner,
        uint256 spaceTokenId
    );

    event TokenSpaceRemoved(
        uint256 indexed _tokenId,
        address owner 
    );

    function tokenMetadataURI(uint256 tokenId)
        external
        view
        returns (string memory);

    function tokenLandCoordinates(uint256 tokenId)
        external
        view
        returns (int,int);

    function allCoordinates()
        external
        view
        returns (int[] memory,int[] memory);

    function mint(LandData calldata data, ILandExchange.BidShares calldata bidShares)
        external;

    function mintMultiple(LandData[] calldata data, ILandExchange.BidShares[] calldata bidShares)
        external;
 
    function listTransfer(uint256 tokenId, address recipient) external; 
    function setAsk(uint256 tokenId, ILandExchange.Ask calldata ask) external; 
    function removeAsk(uint256 tokenId) external; 
    function setBid(uint256 tokenId, ILandExchange.Bid calldata bid) external; 
    function removeBid(uint256 tokenId) external; 
    function acceptBid(uint256 tokenId, ILandExchange.Bid calldata bid) external; 
    function revokeApproval(uint256 tokenId) external; 
    function updateTokenURI(uint256 tokenId, string calldata tokenURI) external;
    function checkSpaceAttach(uint256 tokenId, address sender) external view returns (bool);

    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    ) external;
 
     function updateLandOperatorAddress(
        address newLandOperatorAddress
    ) external;

    function updateTokenSpace(
        uint256 tokenId,
        uint256 spaceTokenId
    ) external; 
}
