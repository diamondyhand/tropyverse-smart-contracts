// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interface/ITropyverseTicketFactory.sol";
import "./interface/ITropyverseMarket.sol";
import "./TropyverseStructure.sol";

import "hardhat/console.sol";

contract TropyverseEducationTicket is Ownable, ERC721Enumerable {
    uint256 private _tokenIdCounter = 0;

    string private collectionUri;
    string[] private details;

    uint256 private immutable vipSupply;
    uint256 private immutable standardSupply;
    uint256 private vipPrice;
    uint256 private standardPrice;
    uint256 private vipSold = 0;
    uint256 private standardSold = 0;
    uint256 immutable MAX_SUPPLY;
    uint256 immutable startDate;
    uint256 private immutable duration;
    uint256 private immutable sessions;
    uint256 vipCounter = 0;
    uint256 standardCounter = 0;
    uint256 immutable landId;

    address private operator;

    mapping(uint256 => uint256) tokenTypes;

    modifier onlyOperator() {
        require(msg.sender == operator, "Caller is not operator");
        _;
    }

    constructor(
        string[] memory _details,
        TropyverseStructure.TicketFeatures memory _features,
        address _operator
    ) ERC721(_details[0], "TRPEDT") {
        // address author = ITropyverseMarket(_market).checkLandOperator(_landId);
        // require(msg.sender == author, "Caller is not eligible to create item");

        collectionUri = _details[1];
        details = _details;
        landId = _features.landId;
        vipSupply = _features.vipSupply;
        standardSupply = _features.standardSupply;
        vipPrice = _features.vipPrice;
        standardPrice = _features.standardPrice;
        startDate = _features.startDate;
        duration = _features.duration;
        sessions = _features.sessions;

        MAX_SUPPLY = _features.vipSupply + _features.standardSupply;
        operator = _operator;
    }

    function _baseURI() internal view override returns (string memory) {
        return collectionUri;
    }

    function buy(
        address _reciever,
        uint256 _type
    ) external onlyOperator returns (uint256 _tokenId) {
        require(totalSupply() < MAX_SUPPLY, "LIMIT_SUPPLY");
        if (_type == 1) {
            require(vipCounter < vipSupply, "Maximum VIP reached");
        } else {
            require(
                standardCounter < standardSupply,
                "Maximum standard reached"
            );
        }
        handleMint(_reciever, _type);

        return _tokenIdCounter;
    }

    function handleMint(address _reciever, uint256 _type) internal {
        _tokenIdCounter = _tokenIdCounter + 1;
        _safeMint(_reciever, _tokenIdCounter);
        tokenTypes[_tokenIdCounter] = _type;
        if (_type == 1) {
            vipCounter++;
            vipSold++;
        } else {
            standardCounter++;
            standardSold++;
        }
    }

    function getCollectionDetails()
        external
        view
        returns (
            address contractAddress,
            string[] memory _details,
            uint256 _landId,
            uint256 vSupply,
            uint256 stdSupply,
            uint256 vPrice,
            uint256 sPrice,
            uint256 vSold,
            uint256 stdSold,
            uint256 sDate,
            uint256 dur
        )
    {
        return (
            address(this),
            details,
            landId,
            vipSupply,
            standardSupply,
            vipPrice,
            standardPrice,
            vipSold,
            standardSold,
            startDate,
            duration
        );
    }

    function getToken(
        uint256 _id
    )
        external
        view
        returns (
            address contractAddress,
            address ticketOwner,
            uint256 _landId,
            uint256 ticketPrice,
            string memory tokenType
        )
    {
        return (
            address(this),
            ownerOf(_id),
            landId,
            tokenTypes[_id] == 1 ? vipPrice : standardPrice,
            tokenTypes[_id] == 1 ? "VIP" : "Standard"
        );
    }

    function getOwner() external view returns (address _collectionOwner) {
        return owner();
    }

    function setOwner(address _newOwner) external onlyOwner {
        transferOwnership(_newOwner);
    }

    function getPrice(
        uint256 _tokenType
    ) external view returns (uint256 price) {
        return (_tokenType == 1 ? vipPrice : standardPrice);
    }

    function setPrice(
        uint256 _tokenType,
        uint256 newPrice
    ) external onlyOperator {
        if (_tokenType == 1) {
            vipPrice = newPrice;
        } else {
            standardPrice = newPrice;
        }
    }

    function getMaxSupply() external view returns (uint256 supply) {
        return vipSupply + standardSupply;
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function getOperator() external view returns (address _operator) {
        return operator;
    }

    function getVipSold() external view returns (uint256 _vipSold) {
        return vipSold;
    }

    function getTotalSupply(
        uint256 _tokenType
    ) external view returns (uint256 _supply) {
        return _tokenType == 1 ? vipSupply : standardSupply;
    }

    function getTotalSupply() external view returns (uint256 _supply) {
        return MAX_SUPPLY;
    }
}
