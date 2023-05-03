// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./NftMinting.sol";
import "./NFTFACTORY.sol";

contract NFTMarketplace is Ownable, ReentrancyGuard {
    uint256 public marketServiceFee = 2;

    // STRUCTS
    struct listStruct {
        address nft;
        uint256 itemId;
        uint256 price;
        address seller;
        bool completed;
        address updateBy;
        address createdBy;
        uint256 updatedAt;
        uint256 listedAt;
        uint256 expiryTime;
    }

    struct listBundleStruct {
        address nft;
        uint256[] itemIds;
        uint256 price;
        address seller;
        bool sold;
        uint256 listedAt;
        uint256 expiryTime;
    }

    struct AuctionStruct {
        uint256 itemId;
        uint256 intialPrice;
        uint256 lastBidPrice;
        uint256 currentBidPrice;
        uint256 expiryTime;
        address winner;
        bool completed;
        address createdBy;
        uint256 createdAt;
        uint256 updatedAt;
    }

    // MAPPING
    mapping(uint256 => listStruct) private Lists;
    mapping(uint256 => bool) private isListed;
    mapping(uint256 => AuctionStruct) private Auctions;
    mapping(uint256 => bool) public isBundle;
    listBundleStruct[] public bundleList;

    // Events
    event ListEvent(
        string operation, // function hit
        address nft,
        uint256 indexed itemId,
        uint256 price,
        address seller,
        bool completed,
        string status,
        uint256 listedAt,
        uint256 expiryTime
    );

    event BundleEvent(
        string operation, // function hit
        address nft,
        uint256[] itemId,
        uint256 price,
        address seller,
        bool sold,
        uint256 listedAt,
        uint256 expiry
    );

    event AuctionEvent(
        string operation, // function hit
        address nft,
        uint256 indexed itemId,
        address seller,
        uint256 intialPrice,
        uint256 lastBidPrice,
        uint256 currentBidPrice,
        address winner,
        string status,
        bool completed,
        address createdBy,
        uint256 createdAt,
        uint256 expiryTime
    );

    // MODIFIERS
    modifier onlyNFTOwner(uint256 _itemId) {
        listStruct memory List = Lists[_itemId];
        IERC721 nft = IERC721(List.nft);
        require(nft.ownerOf(_itemId) == msg.sender, "NOT NFT owner");
        _;
    }

    // FUNCTIONS
    function getBundle(uint256 _index)
        public
        view
        returns (listBundleStruct memory)
    {
        return bundleList[_index];
    }

    //  Bundle Listing
    function createBundle(
        address _nft,
        uint256[] memory _itemId,
        uint256 _price,
        uint256 _expiryTime
    ) public {
        for (uint256 i; i < _itemId.length; i++) {
            isBundle[_itemId[i]] = true;
            require(
                NftMinting(_nft).ownerOf(_itemId[i]) == msg.sender,
                "NOT Owner"
            );
            require(
                _expiryTime > block.timestamp,
                "expiry time should be greater than  curren time"
            );
        }

        bundleList.push(
            listBundleStruct(
                _nft,
                _itemId,
                _price,
                msg.sender,
                false,
                block.timestamp,
                _expiryTime
            )
        );
        emit BundleEvent(
            "Create Bundle",
            _nft,
            _itemId,
            _price,
            msg.sender,
            false,
            block.timestamp,
            _expiryTime
        );
        // return(Bundle[_itemId]);
    }

    function lowerBundlePrice(uint256 _index, uint _price) external {
        listBundleStruct memory bundle = bundleList[_index];
        require(bundle.seller == msg.sender, "You are not the seller");
        bundle.price =_price;
        emit BundleEvent (
            "Lower price",
            bundle.nft,
            bundle.itemIds,
            _price,
            msg.sender,
            false,
            bundle.listedAt,
            bundle.expiryTime
        );
    }

    function cancelbundle(uint256 _index) external {
        listBundleStruct memory Bundle = bundleList[_index];
        require(Bundle.seller == msg.sender, "Only owner can Delete");

        emit BundleEvent(
            "Cancel Bundle",
            Bundle.nft,
            Bundle.itemIds,
            Bundle.price,
            msg.sender,
            false,
            Bundle.listedAt,
            Bundle.expiryTime
        );
        delete Bundle;
    }

    // Buy Bundle At fixed Price
    function buyBundle(uint256 _index, address _nftFactory) external payable {
        require(msg.value == bundleList[_index].price, "Invalid Price");
        if (bundleList[_index].expiryTime > block.timestamp) {
            for (uint256 i; i < bundleList[_index].itemIds.length; i++) {
                if (!bundleList[_index].sold) {
                    // Transfer NFT to buyer
                    IERC721(bundleList[_index].nft).transferFrom(
                        bundleList[_index].seller,
                        msg.sender,
                        bundleList[_index].itemIds[i]
                    );
                    isBundle[bundleList[_index].itemIds[i]] = false;
                } else {
                    revert("ERRORRRRR");
                }
            }
            bundleList[_index].sold = true;
            if (bundleList[_index].sold) {
                NFTFactory _NftFactory = NFTFactory(_nftFactory);

                // transfer market service fee to marketPlace owner
                uint256 serviceFee = (bundleList[_index].price *
                    marketServiceFee) / 100;
                (bool isServiceFeePaid, ) = payable(address(this.owner())).call{
                    value: serviceFee
                }("");
                require(
                    isServiceFeePaid,
                    "Amoun not send to market place owner"
                );

                uint256 _royaltyFee = (bundleList[_index].price *
                    _NftFactory._royaltyPercentage()) / 100;
                if (_royaltyFee > 0) {
                    (bool isRoyaltyFeePaid, ) = payable(
                        bundleList[_index].seller
                    ).call{value: _royaltyFee}("");
                    require(isRoyaltyFeePaid, "Amoun not send to onwer");
                }

                // transfer listed amount to seller
                uint256 remainingPrice = bundleList[_index].price -
                    serviceFee -
                    _royaltyFee;
                (bool isActualAmountPaid, ) = payable(bundleList[_index].seller)
                    .call{value: remainingPrice}("");
                require(isActualAmountPaid, "Amount not send to onwer");
            }

            listBundleStruct(
                bundleList[_index].nft,
                bundleList[_index].itemIds,
                bundleList[_index].price,
                msg.sender,
                true,
                bundleList[_index].listedAt,
                bundleList[_index].expiryTime
            );

            emit BundleEvent(
                "Buy Bundle",
                bundleList[_index].nft,
                bundleList[_index].itemIds,
                bundleList[_index].price,
                msg.sender,
                true,
                bundleList[_index].listedAt,
                bundleList[_index].expiryTime
            );
            delete bundleList[_index];
        } else {
            revert("Bundle Listing Time Expired");
        }
    }

    // Put item on sale a)Fixed price b)Auction c)Make Offer
    function listItem(
        address _nft,
        uint256 _itemId,
        uint256 _price,
        string memory _type,
        uint256 _expiryTime
    ) public {
        // itemStruct memory item = Items[_itemId];
        IERC721 nft = IERC721(_nft); //calling nft.sol address from itemStruct
        require(nft.ownerOf(_itemId) == msg.sender, "NOT NFT OWNER");
        require(!isBundle[_itemId], "Nft already listed as bundle");
        if (
            keccak256(abi.encodePacked(_type)) ==
            keccak256(abi.encodePacked("fixed_price"))
        ) {
            // require(nft.ownerOf(item.tokenId) == msg.sender,"not NFT owner !!!");
            require(
                _expiryTime > block.timestamp,
                "Expiry time should be greater than current time"
            );
            require(_price > 0, "Price should be greater than zero");

            Lists[_itemId] = listStruct({
                nft: _nft,
                itemId: _itemId,
                price: _price,
                seller: msg.sender,
                completed: false,
                updateBy: msg.sender,
                createdBy: NftMinting(_nft).owner(),
                updatedAt: block.timestamp,
                listedAt: block.timestamp,
                expiryTime: _expiryTime
            });
            isListed[_itemId] = true;
            emit ListEvent(
                "Fixed Price / List Item",
                Lists[_itemId].nft,
                _itemId,
                _price,
                msg.sender, // seller
                false,
                "created",
                block.timestamp,
                _expiryTime
            );
        } else if (
            // auction
            keccak256(abi.encodePacked(_type)) ==
            keccak256(abi.encodePacked("timed_auction"))
        ) {
            Lists[_itemId] = listStruct({
                nft: _nft,
                itemId: _itemId,
                price: _price,
                seller: msg.sender,
                completed: false,
                updateBy: msg.sender,
                createdBy: NftMinting(_nft).owner(),
                updatedAt: block.timestamp,
                listedAt: block.timestamp,
                expiryTime: _expiryTime
            });
            isListed[_itemId] = true;
            createAuction(_itemId, _price, _expiryTime);
            emit ListEvent(
                "Create Auction / List Item",
                Lists[_itemId].nft,
                _itemId,
                _price,
                msg.sender, // seller
                false,
                "created",
                Lists[_itemId].listedAt,
                _expiryTime
            );
        } else {
            revert("Enter correct Type");
        }
    }

    // Cancel Item from List
    function cancelListedItem(uint256 _itemId) external {
        listStruct memory list = Lists[_itemId];
        // NFT nft = NFT(item.nftAddress);

        // require(IERC721.ownerOf(.tokenId) == msg.sender,"not listed owner");

        emit ListEvent(
            "Cancel List Item",
            Lists[_itemId].nft,
            _itemId,
            list.price,
            msg.sender,
            false,
            "canceled",
            block.timestamp,
            list.expiryTime // Time when item is removed from sale
        );
        delete Lists[_itemId]; //delete the itemId stored in ListMapping
    }

    // Lower Fixed Price
    function lowerListedPrice(uint256 _itemId, uint256 _price)
        external
        onlyNFTOwner(_itemId)
    {
        require(_price < Lists[_itemId].price, "price should be less");
        require(
            IERC721(Lists[_itemId].nft).ownerOf(_itemId) == msg.sender,
            "NOT OWNER"
        );
        Lists[_itemId].price = _price;
        emit ListEvent(
            "Fixed Price / List Item",
            Lists[_itemId].nft,
            _itemId,
            _price,
            msg.sender, // seller
            false,
            "created",
            block.timestamp,
            Lists[_itemId].expiryTime
        );
    }

    // Buy listed NFT
    function buyItem(address _nftFactory, uint256 _itemId) external payable {
        listStruct memory list = Lists[_itemId];
        // IERC721 nft = IERC721(item.nftAddress);
        require(!list.completed, "NFT alread sold");
        require(list.expiryTime > block.timestamp, "Sale expired!!!!!!");
        require(msg.value == list.price, "Invalid price");

        NFTFactory _NftFactory = NFTFactory(_nftFactory);

        // transfer market service fee to marketPlace owner
        uint256 serviceFee = (list.price * marketServiceFee) / 100;
        (bool isServiceFeePaid, ) = payable(address(this.owner())).call{
            value: serviceFee
        }("");
        require(isServiceFeePaid, "Amoun not send to market place owner");

        uint256 _royaltyFee = (list.price * _NftFactory._royaltyPercentage()) /
            100;
        if (_royaltyFee > 0) {
            (bool isRoyaltyFeePaid, ) = payable(list.createdBy).call{
                value: _royaltyFee
            }("");
            require(isRoyaltyFeePaid, "Amoun not send to onwer");
        }

        // transfer listed amount to seller
        uint256 remainingPrice = list.price - serviceFee - _royaltyFee;
        (bool isActualAmountPaid, ) = payable(list.seller).call{
            value: remainingPrice
        }("");
        require(isActualAmountPaid, "Amoun not send to onwer");

        // Transfer NFT to buyer
        IERC721(list.nft).transferFrom(list.seller, msg.sender, list.itemId);

        // calling List struct
        Lists[_itemId] = listStruct({
            nft: list.nft,
            itemId: _itemId,
            price: list.price,
            seller: msg.sender,
            completed: true,
            updateBy: msg.sender,
            createdBy: list.createdBy,
            updatedAt: block.timestamp,
            listedAt: list.listedAt,
            expiryTime: list.expiryTime
        });

        // calling List Event
        emit ListEvent(
            "Buy Item",
            Lists[_itemId].nft,
            _itemId,
            list.price,
            msg.sender,
            true,
            "bought",
            block.timestamp,
            list.expiryTime
        );

        delete Lists[_itemId];
    }

    // create auction
    function createAuction(
        uint256 _itemId,
        uint256 _minBid,
        uint256 _expiryTime
    ) internal {
        listStruct memory List = Lists[_itemId];
        // IERC721 nft = IERC721(List.nft);
        // require(nft.ownerOf(_itemId) == msg.sender,"Not NFT owner");
        require(
            _expiryTime > block.timestamp,
            "Expiry time should be greater than start time"
        );

        Auctions[_itemId] = AuctionStruct({
            itemId: _itemId,
            intialPrice: _minBid,
            lastBidPrice: 0,
            currentBidPrice: 0,
            expiryTime: _expiryTime,
            winner: List.seller,
            completed: false,
            createdBy: msg.sender,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit AuctionEvent(
            "Create Auction / List Item",
            List.nft,
            _itemId,
            List.seller,
            _minBid,
            _minBid,
            _minBid,
            List.seller,
            "created",
            false,
            msg.sender,
            block.timestamp,
            _expiryTime
        );
    }

    // cancelisl Auction
    function cancelAuction(uint256 _itemId) external {
        // itemStruct memory item = Items[_itemId];/
        listStruct memory List = Lists[_itemId];
        AuctionStruct memory auction = Auctions[_itemId];
        // NFT nft = NFT(item.nftAddress);

        require(
            IERC721(List.nft).ownerOf(List.itemId) == msg.sender,
            "Not NFT owner"
        );
        require(
            block.timestamp < auction.expiryTime,
            "Auction already stopped"
        );
        require(!auction.completed, "Auction already completed");

        // return amount to last bidder
        if (auction.winner != List.seller) {
            (bool isAmountReturned, ) = payable(auction.winner).call{
                value: auction.currentBidPrice
            }("");
            require(isAmountReturned, "Amount not returned to last bidder");
        }

        emit AuctionEvent(
            "Cancel Auction",
            List.nft,
            _itemId,
            msg.sender,
            auction.intialPrice,
            auction.lastBidPrice,
            auction.currentBidPrice,
            List.seller,
            "canceled",
            false,
            msg.sender,
            block.timestamp,
            block.timestamp // time when auction is canceled
        );
        delete Auctions[_itemId];
    }

    // Place your Bid
    function bidPlace(uint256 _itemId, uint256 _bidPrice) external payable {
        listStruct memory list = Lists[_itemId];
        AuctionStruct memory auction = Auctions[_itemId];
        // IERC721 nft = IERC721(list.nft);
        if (auction.winner == list.seller) {
            require(
                _bidPrice >= auction.intialPrice,
                "Bid price should be greater or equal to intial Price"
            );
        }
        require(auction.expiryTime > block.timestamp, "Auction Expired");
        // require(auction.winner != msg.sender,"You are already a highest bidder");
        require(msg.value == _bidPrice, "invalid price");
        require(
            _bidPrice > auction.currentBidPrice,
            "Bid price should be greater than current bid price"
        );
        // require(nft.ownerOf(list.itemId) != msg.sender, "You are aleady a owner of this item");
        require(!auction.completed, "Auction already completed");

        // return amount to last bidder
        if (auction.winner != list.seller) {
            (bool isAmountReturned, ) = payable(auction.winner).call{
                value: auction.currentBidPrice
            }("");
            require(isAmountReturned, "Amount not returned to last bidder");
        }

        Auctions[_itemId] = AuctionStruct({
            itemId: _itemId,
            intialPrice: auction.intialPrice,
            lastBidPrice: auction.currentBidPrice,
            currentBidPrice: _bidPrice,
            expiryTime: auction.expiryTime,
            winner: msg.sender,
            completed: false,
            createdBy: list.createdBy,
            createdAt: auction.createdAt,
            updatedAt: block.timestamp
        });

        emit AuctionEvent(
            "Bid place",
            list.nft,
            list.itemId,
            list.seller,
            auction.intialPrice,
            auction.currentBidPrice,
            _bidPrice,
            msg.sender,
            "bid placed",
            false,
            list.seller,
            block.timestamp,
            auction.expiryTime
        );
    }

    // Transfer Item to Highest Bidder
    function transferAuctionItem(address _nftFactory, uint256 _itemId)
        external
        payable
    {
        listStruct memory list = Lists[_itemId];
        AuctionStruct memory auction = Auctions[_itemId];
        IERC721 nft = IERC721(list.nft);
        require(nft.ownerOf(_itemId) == msg.sender, "NOT NFT owner");
        require(
            block.timestamp > auction.expiryTime,
            "Auction not expired yet"
        );
        require(!auction.completed, "auction already completed");
        require(auction.winner != msg.sender, "You can't call this function");

        // transfer market service fee to marketPlace owner
        uint256 serviceFee = (auction.currentBidPrice * marketServiceFee) / 100;
        (bool isServiceFeePaid, ) = payable(address(this.owner())).call{
            value: serviceFee
        }("");
        require(isServiceFeePaid, "Amoun not send to market place owner");

        // Transfer Royalty fee to Creator
        NFTFactory _NftFactory = NFTFactory(_nftFactory);
        uint256 _royaltyFee = (auction.currentBidPrice *
            _NftFactory.maximumRoyalty()) / 100;
        if (_royaltyFee > 0) {
            (bool isRoyaltyFeePaid, ) = payable(list.createdBy).call{
                value: _royaltyFee
            }("");
            require(isRoyaltyFeePaid, "Amoun not send to onwer");
        }
        uint256 remainingPrice = auction.currentBidPrice -
            serviceFee -
            _royaltyFee;
        // transfer amount to the seller
        (bool isActualAmountPaid, ) = payable(list.seller).call{
            value: remainingPrice
        }("");
        require(isActualAmountPaid, "Amount not send to owner");

        // Transfer NFT to highest bidder
        IERC721(list.nft).transferFrom(
            list.seller,
            auction.winner,
            list.itemId
        );

        // calling list struct and event
        Lists[_itemId] = listStruct({
            nft: list.nft,
            itemId: _itemId,
            price: auction.currentBidPrice,
            seller: auction.winner,
            completed: true,
            updateBy: msg.sender,
            createdBy: list.seller,
            updatedAt: block.timestamp,
            listedAt: list.listedAt,
            expiryTime: Lists[_itemId].expiryTime
        });
        uint256 _expiryTime = Lists[_itemId].expiryTime;
        emit ListEvent(
            "Transfer Auction Item",
            Lists[_itemId].nft,
            _itemId,
            auction.currentBidPrice,
            msg.sender,
            true,
            "bought",
            block.timestamp, // transfered At
            _expiryTime
        );

        // emit Auction event
        emit AuctionEvent(
            "Transfer Auction Item",
            list.nft,
            list.itemId,
            auction.winner,
            auction.intialPrice,
            auction.lastBidPrice,
            auction.currentBidPrice,
            msg.sender,
            "completed",
            true,
            msg.sender,
            block.timestamp,
            _expiryTime
        );
        delete Lists[_itemId];
        delete Auctions[_itemId];
    }

    function getListedItems(uint256 _itemId)
        public
        view
        returns (listStruct memory)
    {
        return Lists[_itemId];
    }

    function getAuctionItems(uint256 _itemId)
        public
        view
        returns (AuctionStruct memory)
    {
        return Auctions[_itemId];
    }

    function getRoyalty(address _nftFactory, uint256 _itemId)
        public
        view
        returns (uint256)
    {
        listStruct memory List = Lists[_itemId];
        NFTFactory _NftFactory = NFTFactory(_nftFactory);
        uint256 _royaltyFee = (List.price * _NftFactory._royaltyPercentage()) /
            100;
        return _royaltyFee;
    }

    function setMarketServiceFee(uint256 _marketServiceFee) public onlyOwner {
        if (_marketServiceFee <= 10) {
            marketServiceFee = _marketServiceFee;
        } else {
            revert("Fee should be less than or equal to 10");
        }
    }
}