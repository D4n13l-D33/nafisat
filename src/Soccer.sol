// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NFT} from "./SoccerNft.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IERC721.sol";

error EXPIRED();

contract SoccerVault is Ownable, ReentrancyGuard {
    NFT soccer;
    address ERCtoken;
    address soccerNFt;
    mapping(uint256 => Listing) public listings;
    mapping(address => UserPreferences) private _userPreferences;
    mapping(uint256 => Bid) private _bids;
    uint256 public listingId;
    uint256 public totalListings;

    struct Listing {
        uint256 tokenId;
        uint256 price;
        uint88 deadline;
        address lister;
        bool active;
    }

    struct UserPreferences {
        string category;
        uint256 maxPrice;
        bool allowAuctions;
        uint256[] preferredTokenIds;
    }

    struct Bid {
        uint256 tokenId;
        uint256 price;
        uint88 deadline;
        address lister;
        bool active;
        uint256 highestBid;
        uint256 bidBalance;

        uint256 [] priceOfBids;
        address[] bidders;
    }

    Bid [] bids;
    mapping( uint256 => Bid) Createdbids;
    mapping(uint256 => address) winner;
    

    event ListingCreated(uint256 indexed listingId, Listing listing);
    event ListingExecuted(uint256 indexed listingId, Listing listing);
    event ListingEdited(uint256 indexed listingId, Listing listing);
    event BidPlaced(address indexed bidder, uint256 indexed tokenId, uint256 amount);
    event BidWithdrawn(address indexed bidder, uint256 indexed tokenId, uint256 amount);

    constructor(address _token, address _soccerNft) Ownable(msg.sender) {
        ERCtoken = _token;
        soccerNFt = _soccerNft;
    }


function createListing(uint256 price, uint256 durationInSeconds) external {
    require(price >= 100*10**18, "MinPriceTooLow");
    require(durationInSeconds >= 60, "DurationTooShort");

    uint88 deadline = uint88(block.timestamp) + uint88(durationInSeconds);
    listingId++;
    // Update state variables first
    listings[listingId] = Listing({
        tokenId: listingId,
        price: price,
        deadline: deadline,
        lister: msg.sender,
        active: true
    });
    
    totalListings++;

    // Emit the event after updating state variables
    emit ListingCreated(listingId, listings[listingId]);
}
function getBidderslength(uint256 bidId)external view returns(uint256){
    return Createdbids[bidId].bidders.length;

}

function getBidders(uint256 ind, uint256 _bidId)external view returns(address){
    return Createdbids[_bidId].bidders[ind];
}

function executeListing(uint256 _listingId, string calldata tokenUri) external nonReentrant {

    require(_listingId > 0 || _listingId <= listingId, "Listing ID does not exist");
    Listing storage listing = listings[_listingId];
    
    if(block.timestamp > listing.deadline) {
        listing.active = false;
        revert EXPIRED();
    }
    
    // Ensure the listing exists and is active
    require(listing.lister != address(0), "ListingNotExistent");
    //update state listing.active to false
        listing.active = false;
        IERC721(soccerNFt).mintNFT(tokenUri);

    emit ListingExecuted(_listingId, listing);
}


function editListing(uint256 _listingId, uint256 _newPrice, bool _active) external {
    require(_listingId > 0 || _listingId <= listingId, "Listing ID does not exist");
    Listing storage listing = listings[_listingId];
    require(listing.lister == msg.sender, "Not your listing");
    require(listing.lister != address(0), "ListingNotExistent");
    require(listing.active, "ListingNotActive");

    listing.price = _newPrice;
    listing.active = _active;

    emit ListingEdited(_listingId, listing);
}

function setUserPreferences(string calldata category, uint256 maxPrice, bool allowAuctions, uint256[] calldata preferredTokenIds) external {
    // Validate preferredTokenIds
    require(preferredTokenIds.length > 0, "PreferredTokenIdsEmpty");

    _userPreferences[msg.sender] = UserPreferences(
        category,
        maxPrice,
        allowAuctions,
        preferredTokenIds
    );
}

    function getListing(uint256 _listingId) external view returns (Listing memory) {
        require(_listingId <= listingId, "ListingNotExistent");
        return listings[_listingId];
    }

    function getUserPreferences(address user) external view  returns (string memory) {
        return _userPreferences[user].category;
    }
    
    function withdrawFunds(uint256 amount, uint256 bidId) external nonReentrant {
    Bid storage bid = Createdbids[bidId];
    require(msg.sender == bid.lister);
    require(bid.bidBalance >= amount, "Insufficient Balance");
    
    //update balance before transfer
    bid.bidBalance = bid.bidBalance - amount;

    IERC20(ERCtoken).transfer(bid.lister, amount);

}

    function createBid(uint256 _listingId) external {
        require(_listingId > 0 || _listingId <= listingId, "Listing ID does not exist");
        Listing storage listing = listings[_listingId];
        Bid storage bid = Createdbids[_listingId];
        require(listing.lister == msg.sender, "Not your listing");
        require(listing.lister != address(0), "ListingNotExistent");

        bid.lister = msg.sender;
        bid.tokenId = _listingId;
        bid.price = listing.price;
        bid.active = true;
        bid.deadline = uint88(block.timestamp) + uint88(60);

        bids.push(bid);
    }

    function placeBid(uint256 tokenId, uint256 price) external {
        Bid storage bid = Createdbids[tokenId];
        require(block.timestamp <= bid.deadline, "Bid Ended");
        bid.bidders.push(msg.sender);
        bid.priceOfBids.push(price);
        winner[price] = msg.sender;

        emit BidPlaced(msg.sender, tokenId, price);
    }

    function getHighestBid(uint256 bidId) private returns(address Winner) {
        Bid storage bid = Createdbids[bidId];
        for(uint8 i; i< bid.priceOfBids.length; i++){
            if(bid.priceOfBids[i] > bid.highestBid){
                bid.highestBid = bid.priceOfBids[i];
            }
        }
        return Winner = winner[bid.highestBid];

    }

    function executeBid(uint256 bidId) external nonReentrant{
        Bid storage bid = Createdbids[bidId];
        require(block.timestamp > bid.deadline, "Bid not Ended");
        address Winner = getHighestBid(bidId);

        //update state
        bid.active = false;

        bool success = IERC20(ERCtoken).transferFrom(Winner, address(this), bid.highestBid);
        require(success, "Transfer Failed");
        
        uint256 fee = bid.highestBid * 10/100;
        uint256 balance = bid.highestBid - fee;
        bid.bidBalance = balance;

        IERC721(soccerNFt).safeTransferFrom(address(this), Winner, bidId);
    }

    function removeBid(uint256 tokenId) external nonReentrant {
        delete Createdbids[tokenId];
        emit BidWithdrawn(msg.sender, tokenId, 0);
    }
}
