// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CommunityVotingPlatform {

    struct Art {
        uint256 id;
        string name;
        string uri;
        address owner;
        uint256 price;
        uint256 auctionEndTime;
        address highestBidder;
        uint256 highestBid;
        bool isAuctionActive;
        bool isForSale;
    }

    uint256 public artCounter;
    mapping(uint256 => Art) public artPieces;
    mapping(address => uint256) public balances;

    event ArtListed(uint256 artId, string name, string uri, uint256 price);
    event ArtSold(uint256 artId, address buyer, uint256 price);
    event AuctionStarted(uint256 artId, uint256 auctionEndTime);
    event NewBid(uint256 artId, address bidder, uint256 bidAmount);
    event AuctionEnded(uint256 artId, address winner, uint256 winningBid);

    modifier onlyOwner(uint256 _artId) {
        require(msg.sender == artPieces[_artId].owner, "You are not the owner of this art");
        _;
    }

    modifier isAuctionActive(uint256 _artId) {
        require(artPieces[_artId].isAuctionActive, "Auction not active for this art");
        _;
    }

    modifier isNotAuctionActive(uint256 _artId) {
        require(!artPieces[_artId].isAuctionActive, "Auction is already active for this art");
        _;
    }

    modifier hasEnoughFunds(uint256 _amount) {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        _;
    }

    // List a new art piece for sale
    function listArtForSale(string memory _name, string memory _uri, uint256 _price) external {
        artCounter++;
        uint256 artId = artCounter;

        artPieces[artId] = Art({
            id: artId,
            name: _name,
            uri: _uri,
            owner: msg.sender,
            price: _price,
            auctionEndTime: 0,
            highestBidder: address(0),
            highestBid: 0,
            isAuctionActive: false,
            isForSale: true
        });

        emit ArtListed(artId, _name, _uri, _price);
    }

    // Buy art directly at the listed price
    function buyArt(uint256 _artId) external hasEnoughFunds(artPieces[_artId].price) {
        Art storage art = artPieces[_artId];
        require(art.isForSale, "This art is not for sale");

        art.owner = msg.sender;
        art.isForSale = false;
        balances[msg.sender] -= art.price;
        balances[art.owner] += art.price;

        emit ArtSold(_artId, msg.sender, art.price);
    }

    // Start auction for an art piece
    function startAuction(uint256 _artId, uint256 _auctionDuration) external onlyOwner(_artId) isNotAuctionActive(_artId) {
        Art storage art = artPieces[_artId];
        art.isAuctionActive = true;
        art.auctionEndTime = block.timestamp + _auctionDuration;

        emit AuctionStarted(_artId, art.auctionEndTime);
    }

    // Place a bid in an auction
    function placeBid(uint256 _artId) external hasEnoughFunds(artPieces[_artId].highestBid + 1) isAuctionActive(_artId) {
        Art storage art = artPieces[_artId];
        require(block.timestamp < art.auctionEndTime, "Auction has ended");

        uint256 bidAmount = art.highestBid + 1; // Set bid to be higher than current highest bid

        // Refund the previous highest bidder if there is one
        if (art.highestBidder != address(0)) {
            balances[art.highestBidder] += art.highestBid;
        }

        art.highestBidder = msg.sender;
        art.highestBid = bidAmount;
        balances[msg.sender] -= bidAmount;

        emit NewBid(_artId, msg.sender, bidAmount);
    }

    // End auction and transfer ownership of the art piece to the highest bidder
    function endAuction(uint256 _artId) external onlyOwner(_artId) isAuctionActive(_artId) {
        Art storage art = artPieces[_artId];
        require(block.timestamp >= art.auctionEndTime, "Auction has not ended yet");

        art.isAuctionActive = false;
        art.owner = art.highestBidder;
        balances[art.owner] += art.highestBid;

        emit AuctionEnded(_artId, art.highestBidder, art.highestBid);
    }

    // Deposit funds into the platform's account
    function depositFunds() external payable {
        balances[msg.sender] += msg.value;
    }

    // Withdraw funds from the platform's account
    function withdrawFunds(uint256 _amount) external hasEnoughFunds(_amount) {
        balances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // Get the details of a specific art piece
    function getArtDetails(uint256 _artId) external view returns (Art memory) {
        return artPieces[_artId];
    }
}
