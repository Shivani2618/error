// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title MetaMint Studio
 * @dev NFT Minting Platform with royalty management and metadata storage
 * @notice This contract allows users to mint, transfer, and manage NFTs with built-in royalty support
 */
contract Project is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    
    // Token ID counter for unique NFT identification
    Counters.Counter private _tokenIds;
    
    // Minting fee in wei
    uint256 public mintingFee = 0.01 ether;
    
    // Maximum supply of NFTs
    uint256 public maxSupply = 10000;
    
    // Royalty percentage (in basis points, 250 = 2.5%)
    uint256 public royaltyPercentage = 250;
    
    // Struct to store NFT metadata
    struct NFTMetadata {
        uint256 tokenId;
        address creator;
        address currentOwner;
        string tokenURI;
        uint256 mintedAt;
        uint256 royaltyPercentage;
    }
    
    // Mapping from token ID to NFT metadata
    mapping(uint256 => NFTMetadata) public nftMetadata;
    
    // Mapping to track total minted NFTs by creator
    mapping(address => uint256) public creatorMintCount;
    
    // Events
    event NFTMinted(
        uint256 indexed tokenId,
        address indexed creator,
        string tokenURI,
        uint256 timestamp
    );
    
    event NFTTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 timestamp
    );
    
    event MintingFeeUpdated(uint256 oldFee, uint256 newFee);
    
    event RoyaltyPaid(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 amount
    );
    
    /**
     * @dev Constructor to initialize the NFT collection
     * @param initialOwner Address of the contract owner
     */
    constructor(address initialOwner) 
        ERC721("MetaMint Studio NFT", "MMNFT") 
        Ownable(initialOwner) 
    {}
    
    /**
     * @dev Mint a new NFT
     * @param tokenURI The metadata URI for the NFT
     * @return newTokenId The ID of the newly minted NFT
     */
    function mintNFT(string memory tokenURI) 
        public 
        payable 
        returns (uint256) 
    {
        require(msg.value >= mintingFee, "Insufficient minting fee");
        require(_tokenIds.current() < maxSupply, "Maximum supply reached");
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        // Mint the NFT to the caller
        _mint(msg.sender, newTokenId);
        
        // Set the token URI
        _setTokenURI(newTokenId, tokenURI);
        
        // Store NFT metadata
        nftMetadata[newTokenId] = NFTMetadata({
            tokenId: newTokenId,
            creator: msg.sender,
            currentOwner: msg.sender,
            tokenURI: tokenURI,
            mintedAt: block.timestamp,
            royaltyPercentage: royaltyPercentage
        });
        
        // Update creator mint count
        creatorMintCount[msg.sender]++;
        
        emit NFTMinted(newTokenId, msg.sender, tokenURI, block.timestamp);
        
        return newTokenId;
    }
    
    /**
     * @dev Batch mint multiple NFTs
     * @param tokenURIs Array of metadata URIs
     * @return tokenIds Array of newly minted token IDs
     */
    function batchMintNFT(string[] memory tokenURIs) 
        public 
        payable 
        returns (uint256[] memory) 
    {
        require(
            msg.value >= mintingFee * tokenURIs.length,
            "Insufficient minting fee for batch"
        );
        require(
            _tokenIds.current() + tokenURIs.length <= maxSupply,
            "Exceeds maximum supply"
        );
        
        uint256[] memory tokenIds = new uint256[](tokenURIs.length);
        
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            tokenIds[i] = mintNFT(tokenURIs[i]);
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Transfer NFT with royalty payment to original creator
     * @param from Current owner address
     * @param to New owner address
     * @param tokenId Token ID to transfer
     */
    function transferWithRoyalty(
        address from,
        address to,
        uint256 tokenId
    ) public payable {
        require(ownerOf(tokenId) == from, "Invalid current owner");
        require(msg.value > 0, "Transfer value must be greater than 0");
        
        NFTMetadata storage metadata = nftMetadata[tokenId];
        
        // Calculate royalty amount
        uint256 royaltyAmount = (msg.value * metadata.royaltyPercentage) / 10000;
        uint256 sellerAmount = msg.value - royaltyAmount;
        
        // Pay royalty to creator
        if (royaltyAmount > 0 && metadata.creator != from) {
            payable(metadata.creator).transfer(royaltyAmount);
            emit RoyaltyPaid(tokenId, metadata.creator, royaltyAmount);
        }
        
        // Pay seller
        payable(from).transfer(sellerAmount);
        
        // Transfer NFT
        _transfer(from, to, tokenId);
        
        // Update metadata
        metadata.currentOwner = to;
        
        emit NFTTransferred(tokenId, from, to, block.timestamp);
    }
    
    /**
     * @dev Get NFT metadata by token ID
     * @param tokenId Token ID to query
     * @return NFT metadata struct
     */
    function getNFTMetadata(uint256 tokenId) 
        public 
        view 
        returns (NFTMetadata memory) 
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return nftMetadata[tokenId];
    }
    
    /**
     * @dev Get all NFTs owned by an address
     * @param owner Address to query
     * @return Array of token IDs
     */
    function getNFTsByOwner(address owner) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256 totalSupply = _tokenIds.current();
        uint256 ownerBalance = balanceOf(owner);
        uint256[] memory result = new uint256[](ownerBalance);
        uint256 counter = 0;
        
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (_ownerOf(i) == owner) {
                result[counter] = i;
                counter++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get total number of minted NFTs
     * @return Total supply
     */
    function getTotalMinted() public view returns (uint256) {
        return _tokenIds.current();
    }
    
    /**
     * @dev Update minting fee (only owner)
     * @param newFee New minting fee in wei
     */
    function setMintingFee(uint256 newFee) public onlyOwner {
        uint256 oldFee = mintingFee;
        mintingFee = newFee;
        emit MintingFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Update royalty percentage (only owner)
     * @param newRoyaltyPercentage New royalty percentage in basis points
     */
    function setRoyaltyPercentage(uint256 newRoyaltyPercentage) 
        public 
        onlyOwner 
    {
        require(newRoyaltyPercentage <= 1000, "Royalty cannot exceed 10%");
        royaltyPercentage = newRoyaltyPercentage;
    }
    
    /**
     * @dev Withdraw contract balance (only owner)
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev Check if a token exists
     * @param tokenId Token ID to check
     * @return Boolean indicating existence
     */
    function tokenExists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
