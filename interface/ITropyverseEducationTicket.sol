//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseEducationTicket {
    function mint(address buyer) external;

    function getPrice(uint256 _tokenType) external view returns (uint256 price);

    function getTotalSupply(uint256 _tokenType)
        external
        view
        returns (uint256 supply);

    function getOwner() external view returns (address _contractOwner);

    function setOwner() external;

    function setPrice(uint256 _tokenType, uint256 newPrice) external;
}
