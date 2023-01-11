//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseGood {
    function buy(address reciever)
        external
        returns (
            address _owner,
            address _collection,
            string[] memory _details,
            uint256 tokenId,
            uint256 _price,
            uint256 _landId
        );

    function setOwner(address newOwner) external;

    function getOwner() external view returns (address _owner);

    function getPrice() external view returns (uint256 price);

    function setPrice(uint256 newPrice) external;
}
