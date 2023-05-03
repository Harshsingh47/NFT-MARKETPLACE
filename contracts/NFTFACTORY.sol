// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./NftMinting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
    
contract NFTFactory is Ownable {
    NftMinting[] public allCollections;
    mapping(address => NftMinting[]) public userCollecions;
    uint256 public maximumRoyalty = 10;
    uint256 public _royaltyPercentage;

    event CollectionCreated(address owner, string name ,NftMinting deployedAt);

    function createCollection(
        string memory NAME,
        string memory SYMBOL,
        uint256 royaltyPercentage,
        address royaltyReceiver
        )
        public
        returns(NftMinting )
    {   
        require(royaltyPercentage <= maximumRoyalty, "Invalid Royalty!");
        _royaltyPercentage = royaltyPercentage;
        NftMinting nftContract = new NftMinting(NAME, SYMBOL,royaltyPercentage,royaltyReceiver);
        userCollecions[msg.sender].push(nftContract);
        nftContract.transferOwnership(msg.sender);
        allCollections.push(nftContract);
        emit CollectionCreated(msg.sender, NAME, nftContract);
        return nftContract;
    }

    function getUserCollection(address _user)
        public
        view
        returns (NftMinting[] memory)
    {
        return userCollecions[_user];
    }

    function getAllCollection() public view returns (NftMinting[] memory) {
        return allCollections;
    }
}