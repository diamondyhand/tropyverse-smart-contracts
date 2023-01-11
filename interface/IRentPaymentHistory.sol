// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IRentPaymentHistory {
    struct Payment {
        address sender;
        address receiver;
        uint256 tokenId;
        uint256 amount;
        uint256 startDate;
        uint256 expirationDate;
        uint256 date;
    }

    function payRent(
        address _sender,
        address _receiver,
        bool _rentType,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _start,
        uint256 _expiration
    ) external returns (Payment memory);

    function getPaymentHistory(uint256 _tokenId)
        external
        view
        returns (Payment[] memory payments);
}
