//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseLand {
    function getMintedBalance(address caller) external view returns (uint256);

    function getTotalSupply() external view returns (uint256);

    function getNonce(string memory nonce) external view returns (bool);

    function setNonceUsed(string memory nonce) external;

    function getUsedUri(string memory tokenUri) external view returns (bool);

    function setUsedUri(string memory tokenUri) external;

    function getSignerAddress() external view returns (address);

    function getManager() external view returns (address);

    function setManager(address _manager) external;

    function adminMint(address _to, string memory _uri) external;

    function totalSupply() external returns (uint256);

    function getMaxSupply() external returns (uint256);
}
