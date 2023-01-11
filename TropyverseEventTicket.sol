// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ITropyverseMarket.sol";
import "./interface/ITropyverseTicketFactory.sol";
import "./TropyverseStructure.sol";

contract TropyverseEventTicket is Ownable, ERC721Enumerable {
    uint256 private _tokenIdCounter = 0;

    string private constant SUPPLY_LIMIT_ERROR = "Max Supply reached";
    string private constant PRICE_ERROR = "Price not met";
    string private collectionUri;
    string[] details;

    uint256 private vipSupply;
    uint256 private standardSupply;
    uint256 private immutable MAX_SUPPLY;
    uint256 private immutable startDate;
    uint256 private immutable duration;
    uint256 private vipPrice;
    uint256 private standardPrice;
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
        // uint256 _startDate,
        // uint256 _duration,
        // uint256 _vipSupply,
        // uint256 _standardSupply,
        // uint256 _vipPrice,
        // uint256 _standardPrice,
        // uint256 _landId,
        address _operator
    ) ERC721(_details[0], "TRPEDT") {
        details = _details;
        collectionUri = _details[1];
        landId = _features.landId;
        vipSupply = _features.vipSupply;
        standardSupply = _features.standardSupply;
        vipPrice = _features.vipPrice;
        standardPrice = _features.standardPrice;
        startDate = _features.startDate;
        duration = _features.duration;

        MAX_SUPPLY = _features.vipSupply + _features.standardSupply;

        operator = _operator;
    }

    function _baseURI() internal view override returns (string memory) {
        return collectionUri;
    }

    function buy(address receiver, uint256 _type) external onlyOperator {
        require(totalSupply() + 1 < MAX_SUPPLY, SUPPLY_LIMIT_ERROR);
        if (_type == 1) {
            require(vipCounter < vipSupply, "Maximum VIP reached");
        } else {
            require(
                standardCounter < standardSupply,
                "Maximum standard reached"
            );
        }
        handleMint(receiver, _type);
    }

    function handleMint(address receiver, uint256 _type) internal {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(receiver, tokenId);
        tokenTypes[tokenId] = _type;
        if (_type == 1) {
            vipCounter++;
        } else {
            standardCounter++;
        }
    }

    function setOperator(address _operator)
        external
        returns (address newOperator)
    {
        require(msg.sender == operator, "Caller is not operator");
        operator = _operator;
        return _operator;
    }

    function getPrice(uint256 _tokenType)
        external
        view
        returns (uint256 price)
    {
        return (_tokenType == 1 ? vipPrice : standardPrice);
    }

    function setPrice(uint256 tokenType, uint256 newPrice)
        external
        onlyOperator
    {
        tokenType == 1 ? vipPrice = newPrice : standardPrice = newPrice;
    }

    function getTotalSupply(uint256 _tokenType)
        external
        view
        returns (uint256 supply)
    {
        return (_tokenType == 1 ? vipSupply : standardSupply);
    }

    function getTotalSupply() external view returns (uint256 _supply) {
        return MAX_SUPPLY;
    }
}
