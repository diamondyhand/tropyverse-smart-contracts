//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseTicket {
    function buy(address reciever, uint256 tokenType)
        external
        returns (uint256 _tokenId);

    function setOwner(address newOwner) external;

    function getOwner() external view returns (address _owner);

    function getPrice(uint256 tokenType) external view returns (uint256 price);

    function setPrice(uint256 tokenType, uint256 newPrice) external;
}
