// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ITropyverseMarket.sol";
import "./interface/ITropyverseGoodFactory.sol";

contract TropyverseGood is Ownable, ERC721Enumerable {
    uint256 private _tokenIdCounter = 0;
    uint256 private price;
    uint256 immutable MAX_SUPPLY;
    uint256 immutable landId;

    string private collectionUri;
    string[] private details;

    address private operator;
    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    constructor(
        string[] memory _details,
        uint256 _landId,
        uint256 _totalSupply,
        uint256 _price,
        address _operator
    ) ERC721(_details[0], "TRPG") {
        landId = _landId;
        details = _details;
        MAX_SUPPLY = _totalSupply;
        operator = _operator;
        price = _price;
        collectionUri = details[1];
    }

    function _baseURI() internal view override returns (string memory) {
        return collectionUri;
    }

    function buy(
        address _reciever
    )
        external
        onlyOperator
        returns (
            address _owner,
            address _collection,
            string[] memory _details,
            uint256 _tokenId,
            uint256 _price,
            uint256 _landId
        )
    {
        require(totalSupply() < MAX_SUPPLY, "LIMIT_SUPPLY");
        _tokenIdCounter = _tokenIdCounter + 1;
        _safeMint(_reciever, _tokenIdCounter);

        return (
            owner(),
            address(this),
            details,
            _tokenIdCounter,
            price,
            landId
        );
    }

    function setOperator(
        address _operator
    ) external onlyOwner returns (address newOperator) {
        operator = _operator;
        return _operator;
    }

    function setOwner(address _newOwner) external onlyOwner {
        transferOwnership(_newOwner);
    }

    function getOwner() external view returns (address _owner) {
        return owner();
    }

    function getPrice() external view returns (uint256 _price) {
        return price;
    }

    function setPrice(uint256 newPrice) external onlyOperator {
        price = newPrice;
    }

    function getCollectionDetails()
        external
        view
        returns (
            address _owner,
            address contractAddress,
            string[] memory _details,
            uint256 _landId,
            uint256 _totalSupply,
            uint256 _Price,
            uint256 _totalSold
        )
    {
        return (
            owner(),
            address(this),
            details,
            landId,
            MAX_SUPPLY,
            price,
            totalSupply()
        );
    }
}
