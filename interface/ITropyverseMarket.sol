//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ITropyverseMarket is IERC721Receiver {
    function getTotalLands(address owner) external view returns (uint256 total);

    function checkLandOperator(uint256 _landId)
        external
        view
        returns (address operator);
}
