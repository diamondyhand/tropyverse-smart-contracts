//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseTicketFactory {
    function addEducationCollection(
        address owner,
        address collection,
        string[] memory details,
        uint256 _startDate,
        uint256 _duration,
        uint256 _vipSupply,
        uint256 _standardSupply,
        uint256 _vipPrice,
        uint256 _standardPrice,
        uint256 _landId
    ) external returns (uint256 index);

    function buyEducationTicket(
        address owner,
        address buyer,
        address collection,
        string[] memory details,
        uint256 price,
        uint256 tokenType,
        uint256 landId
    ) external payable;

    function addEventCollection(uint256 landId, address collection) external;

    function buyEventTicket(
        address owner,
        address buyer,
        address collection,
        string[] memory details,
        uint256 price,
        uint256 tokenType,
        uint256 landId
    ) external payable;

    function getLandEducations(uint256 landId)
        external
        returns (address[] memory educationContracts);

    function getLandEvents(uint256 landId)
        external
        returns (address[] memory eventContracts);

    function deleteEducationContract(uint256 landId, uint256 index) external;

    function deleteEventContract(uint256 landId, uint256 index) external;

    function setMarketFee(uint256 marketFee) external;

    function getMarketFee() external view returns (uint256 fee);

    function setOwner() external;

    function getOwner() external view returns (address owner);

    function getMarketContract() external view returns (address market);

    function setMarketContract() external;

    function detachEducationTickets(
        uint256 _landId,
        uint256 reason,
        address remover
    ) external;

    function detachEventTickets(
        uint256 _landId,
        uint256 reason,
        address remover
    ) external;
}
