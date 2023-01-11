//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseEventTicket {
    function mint(address buyer, uint256 _tokenType) external;

    function getPrice(uint256 _tokenType) external view returns (uint256 price);

    function getTotalSupply(uint256 _tokenType)
        external
        view
        returns (uint256 supply);
}
