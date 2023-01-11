//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseGoodFactory {
    function addGoodCollection(
        address owner,
        address collection,
        string[] memory details,
        uint256 price,
        uint256 landId
    ) external returns (uint256 index);

    function buyGood(
        address collection,
        address owner,
        address buyer,
        string[] memory details,
        uint256 price,
        uint256 landId
    ) external;

    function getLandGoods(uint256 landId)
        external
        returns (address[] memory goodContracts);

    function deleteGoodContract(uint256 landId, uint256 index) external;

    function setMarketFee(uint256 marketFee) external;

    function getMarketFee() external view returns (uint256 fee);

    function getOwner() external view returns (address owner);

    function setOwner() external;

    function detachLandGoods(
        uint256 _landId,
        uint256 reason,
        address remover
    ) external;
}
