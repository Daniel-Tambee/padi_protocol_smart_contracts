interface IOldNFT {
    function totalSupply() external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function burn(uint256 oldTokenId) external;
    function owner() external returns (address);
    function transferOwnership(address newOwner) external;


}