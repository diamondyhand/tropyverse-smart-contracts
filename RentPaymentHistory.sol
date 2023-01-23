//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interface/IRentPaymentHistory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract RentPaymentHistory is Ownable {
    address public operator;
    event RentalPaymentReceived(
        address sender,
        address receiver,
        uint256 tokenId,
        uint256 amount,
        uint256 startDate,
        uint256 expirationDate,
        uint256 date
    );
    // rentType  collatheral true or false
    struct Payment {
        address sender;
        address receiver;
        bool rentType;
        uint256 tokenId;
        uint256 amount;
        uint256 startDate;
        uint256 expirationDate;
        uint256 date;
    }
    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || msg.sender == operator,
            "NOT_AUTHORIZED"
        );
        _;
    }

    constructor() {
        operator = msg.sender;
        // console.log("start date is ", block.timestamp);
        // console.log("1 hour later is :", block.timestamp + 1 hours);
        // console.log("1 day later is :", block.timestamp + 1 days);
        // console.log("1 month later is :", block.timestamp + 30 days);
        // console.log("payment date:", block.timestamp + 8 days);
        // console.log("payment date:", block.timestamp + 10 days);
        // console.log("payment date:", block.timestamp + 1 hours);
        // console.log("payment date:", block.timestamp + 60 seconds);
        // console.log("payment date:", block.timestamp + 1 seconds);
        // console.log("expiration Date is   ", block.timestamp + 60 days);
    }

    // mapping(uint256 => Payment[]) public paymentHistory;
    mapping(uint256 => Payment[]) public paymentHistory;

    function payRent(
        address _sender,
        address _receiver,
        bool _rentType,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _start,
        uint256 _expiration
    ) external onlyAuthorized returns (Payment memory) {
        require(
            _expiration >= block.timestamp + 30 minutes,
            "Rent contract is expired"
        );
        // require(_start <= block.timestamp, "Invalid start date");

        Payment memory payment = Payment(
            _sender,
            _receiver,
            _rentType,
            _tokenId,
            _amount,
            _start,
            _expiration,
            block.timestamp
        );

        paymentHistory[_tokenId].push(payment);
        emit RentalPaymentReceived(
            payment.sender,
            payment.receiver,
            payment.tokenId,
            payment.amount,
            payment.startDate,
            payment.expirationDate,
            payment.date
        );
        return payment;
    }

    // this function is used to get history of payment to specific account
    function getPaymentHistory(
        uint256 _tokenId
    ) external view returns (Payment[] memory payments) {
        // require(msg.sender == owner, "Caller is not owner");
        return paymentHistory[_tokenId];
    }

    // this function should return last active rents history
    function getActivePaymentHistory(
        uint256 _tokenId,
        uint256 _start
    ) external view returns (Payment[] memory payments) {
        if (paymentHistory[_tokenId].length == 0) {
            return new Payment[](0);
        }

        uint256 counter = 0;
        uint256 i = paymentHistory[_tokenId].length;

        while (i > 0 && paymentHistory[_tokenId][i - 1].startDate >= _start) {
            counter++;
            i--;
        }

        if (counter == 0) {
            return new Payment[](0);
        }
        Payment[] memory _payments = new Payment[](counter);
        counter = 0;
        i = paymentHistory[_tokenId].length;
        while (i > 0 && paymentHistory[_tokenId][i - 1].startDate >= _start) {
            _payments[counter] = paymentHistory[_tokenId][i];
            counter++;
            i--;
        }

        return _payments;
    }

    function setOwner(address _newOwner) external onlyOwner {
        transferOwnership(_newOwner);
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function setOperator(address newOperator) external onlyOwner {
        operator = newOperator;
    }

    function getOperator() external view returns (address) {
        return operator;
    }
}
