//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";

contract TropyverseStructure is Ownable {
    string public constant SUPPLY_LIMIT_ERROR = "Max Supply reached";
    string public constant PRICE_ERROR = "Price not met";
    struct TicketFeatures {
        uint256 startDate;
        uint256 duration;
        uint256 sessions;
        uint256 vipSupply;
        uint256 standardSupply;
        uint256 vipPrice;
        uint256 standardPrice;
        uint256 landId;
    }

    struct Ticket {
        address contractAddress;
        uint256 tokenType;
        uint256 tokenId;
        uint256 price;
        uint256 landId;
        uint256 marketCommission;
        uint256 ownerCommission;
    }
}
