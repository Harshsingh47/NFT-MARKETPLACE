// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NftMinting is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter _tokenIdTracker;

    mapping(uint256 => string) public _tokenURIs; //returns uris for particular token id
    mapping(uint256 => address) public minter; //returs minter of a token id
    mapping(uint256 => uint256) public royalty; //returns royalty of a token id
    mapping(address => uint256[]) public mintedByUser; //token-ids minted by a user
    mapping(address => bool) private whitelisted; //returns the whitelsited addresses

    uint256 public maximumRoyalty = 10;
    string public _collectionUri;
    uint public royaltyPercentage; 
    address public _royaltyReceiver;
    
    constructor(
        string memory NAME,
        string memory SYMBOL,
        uint256 _royaltyPercent,
        address royaltyReceiver
    ) ERC721(NAME, SYMBOL) {
        require(_royaltyPercent <= maximumRoyalty,"Royalty should be less than 10");
        royaltyPercentage = _royaltyPercent;
        _royaltyReceiver = royaltyReceiver;  
    }
 
    event Minted(string Operation,uint256 itemId, string tokenURI, address createdBy, address nftAddress, uint256 createdAt);

    function RoyaltyInfo(uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        return (_royaltyReceiver,(salePrice *royaltyPercentage / uint256(100))); 
    }
    // tokenURI - IPFS URI
    function mintNft(string memory _tokenURI)
        public
        payable
        returns (uint256)
    {
        _tokenIdTracker.increment();
        uint256 NftId = _tokenIdTracker.current();
        _safeMint(msg.sender, NftId);
        mintedByUser[msg.sender].push(NftId);
        royalty[NftId] = royaltyPercentage;
        minter[NftId] = msg.sender;
        _setTokenURI(NftId, _tokenURI);
        emit Minted(
            "mintNFT",
             NftId,
            _tokenURI,
            msg.sender,
            address(this),
            block.timestamp
            );
        return (NftId);
    }

    function approveMarketplace(address marketPlace, bool approved) public {
        setApprovalForAll(marketPlace, approved);
    }

    // returns minter of a token
    function minterOfToken(uint256 _tokenId)
        external
        view
        returns (address _minter)
    {
        return (minter[_tokenId]);
    }

    // sets uri for a token
    function _setTokenURI(uint256 _tokenId, string memory _tokenURI)
        internal
        virtual
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        _tokenURIs[_tokenId] = _tokenURI;
    }

    function setMaxRoyalty(uint256 _royalty) external onlyOwner {
        maximumRoyalty = _royalty;
    }

    function getNFTMintedByUser(address user)
        external
        view
        returns (uint256[] memory ids)
    {
        return (mintedByUser[user]);
    }

    // returns uri of a particular token

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory _tokenURI = _tokenURIs[tokenId];

        return _tokenURI;
    }

}