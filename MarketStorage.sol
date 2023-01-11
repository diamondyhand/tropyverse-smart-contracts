//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interface/IRentPaymentHistory.sol";
import "./interface/ITropyverseGoodFactory.sol";
import "./interface/ITropyverseTicketFactory.sol";
// import "./TransferProxy.sol";
import "hardhat/console.sol";

// error ItemNotForSale(address nftAddress tokenId);

contract MarketStorage is IERC721Receiver, ReentrancyGuard, Ownable {
    constructor(address _marketContract) {}

    // selectedRentType 1 hourly, 2 daily, 3 monthly
    // expired 1 = finished interval 2 = not payed monthly fee, 3 canceled
    // numberOfPayments = 0 not rented, 2 = start of rent contract,
    struct MarketItem {
        bool listed;
        uint256 numberOfPayments;
        uint256 salePrice;
        uint256 hourlyFee;
        uint256 dailyFee;
        uint256 monthlyFee;
        uint256 selectedRentType;
        uint256 interval;
        uint256 startDate;
        uint256 expirationDate;
        uint256 nextPayment;
        uint256 expired;
        address previousOwner;
        address owner;
        address tenant;
        bool onRent;
        bool onSale;
        bool isCollateral;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function getBalance() external view onlyOwner returns (uint256 balance) {
        return address(this).balance;
    }
    // function transferLand(uint256 _tokenId, address _to)
    //     external
    //     isListed(_tokenId)
    //     onlyOwner
    // {
    //     require(
    //         _to == listings[_tokenId].owner || _to == listings[_tokenId].tenant,
    //         "Invalid address to transfer land"
    //     );
    //     IERC721 nft = IERC721(landContract);
    //     nft.safeTransferFrom(address(this), _to, _tokenId);
    //     delete listings[_tokenId];
    // }
}
