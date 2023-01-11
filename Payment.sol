// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract Payment {
    event TransferGoodItemFund(
        address indexed sender,
        address receiver,
        uint256 landId,
        uint256 goodId,
        uint256 amount,
        uint256 date
    );
    event TransferBecomeAgentFun(
        address indexed sender,
        address receiver,
        uint256 amount,
        uint256 date
    );

    function goodItemPayment(
        address sender,
        address receiver,
        uint256 landId,
        uint256 goodId,
        uint256 amount
    ) external {
        emit TransferGoodItemFund(
            sender,
            receiver,
            landId,
            goodId,
            amount,
            block.timestamp
        );
    }

    function becomeAgentPayment(
        address _sender,
        address _receiver,
        uint256 _amount
    ) external {
        emit TransferBecomeAgentFun(
            _sender,
            _receiver,
            _amount,
            block.timestamp
        );
    }
}
