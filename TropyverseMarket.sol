//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

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

contract TropyverseMarket is IERC721Receiver, ReentrancyGuard, Ownable {
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

    // item is listed for sale
    event ItemListedForSale(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );

    // item price is udpated
    event ItemUpdatedForSale(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );
    // item is bought
    event LandBought(
        address indexed _buyer,
        bool hasTenant,
        uint256 indexed _tokenId,
        uint256 price
    );

    // item is put on rent

    event LandListedForRent(
        address owner,
        uint256 tokenId,
        uint256 hourlyFee,
        uint256 dailyFee,
        uint256 monthlyFee
    );

    // event for removing item from renting status
    event LandUpdatedForRent(
        address owner,
        uint256 tokenId,
        uint256 newHour,
        uint256 newDaily,
        uint256 newMonthly
    );
    event LandRemovedFromRent(address indexed owner, uint256 indexed tokenId);

    // rentType 1 hourly, 2 daily, 3 monthly

    event LandRented(
        uint256 rentType,
        uint256 interval,
        uint256 tokenId,
        uint256 totalPrice,
        uint256 startDate,
        uint256 expirationDate,
        uint256 nextPaymentDate,
        address owner,
        address tenant,
        address agent,
        string email,
        bool isCollateral
    );

    event SaleCanceled(address indexed _seller, uint256 indexed _tokenId);

    event RentCanceledTenant(address tenant, uint256 tokenId);

    event RentalPayment(
        address sender,
        address reciever,
        uint256 landId,
        uint256 marketFee,
        uint256 landLordFee,
        uint256 agentFee,
        uint256 paymentDate
    );

    mapping(uint256 => MarketItem) private listings;
    mapping(string => bool) private usedNonce;

    uint256[] landIds;

    IERC721 private landContract;
    IRentPaymentHistory rentHistory;
    ITropyverseGoodFactory goodFactory;
    ITropyverseTicketFactory ticketFactory;

    uint256 saleServiceFee = 12;
    uint256 rentServiceFee = 25;
    uint256 agentRentcommission = 10;
    address signerAddress;

    modifier notListed(uint256 _tokenId) {
        require(listings[_tokenId].listed == false, "Land is already listed");
        _;
    }
    modifier isListed(uint256 _tokenId) {
        require(listings[_tokenId].listed == true, "Land is not listed");
        _;
    }
    modifier isListedForSale(uint256 _tokenId, address _owner) {
        require(
            listings[_tokenId].onSale == true,
            "Land is not listed for sale"
        );
        _;
    }
    modifier notListedForSale(uint256 _tokenId) {
        require(
            listings[_tokenId].onSale != true,
            "Land is already listed for sale"
        );
        _;
    }
    modifier isListedForRent(uint256 _tokenId) {
        require(
            listings[_tokenId].onRent == true,
            "Land is not listed for rent"
        );
        _;
    }

    // asserts that item is not already listed for rent
    modifier notListedForRent(uint256 _tokenId) {
        require(
            listings[_tokenId].onRent != true,
            "Land is already listed for rent"
        );
        _;
    }

    // 1- if land is on rent but no one rented the land
    // 2- if land is on rent and rented by tenant, but interval is expired (not collatheral)
    // 3- if land is on rent and rented by tenant and tenant fail to meet the repayment (collatheral)
    modifier notRented(uint256 tokenId) {
        if (listings[tokenId].tenant != address(0)) {
            // if land is rented for more than 3 month , then we must check the next payment
            // if tenant fail to meet the repayment, the marketplace has the right to take ownership of land from tenant
            if (listings[tokenId].isCollateral == true) {
                // expiration date must be in the past, so land can be rented by any person

                // this should be checked
                // require(
                //     listings[tokenId].expirationDate < block.timestamp,
                //     "Land is already rented"
                // );
                require(
                    listings[tokenId].nextPayment + 30 days < block.timestamp,
                    "Land is already rented"
                );
            } else {
                require(
                    listings[tokenId].expirationDate < block.timestamp,
                    "Land is already rented"
                );
            }
        }
        _;
    }

    modifier isTenant(address tenant, uint256 tokenId) {
        require(listings[tokenId].tenant == tenant, "Caller is not tenant");
        _;
    }
    // this should be updated not work{
    modifier isRented(uint256 tokenId) {
        require(
            listings[tokenId].tenant != address(0),
            "Trying to call on not rented land"
        );
        // if (listings[tokenId].tenant != address(0)) {
        // if land is rented for more than 3 month , then we must check the next payment
        // if tenant fail to meet the repayment, the marketplace has the right to take ownership of land from tenant
        if (listings[tokenId].isCollateral == true) {
            require(
                listings[tokenId].nextPayment + 30 days > block.timestamp,
                "Trying to call on not rented land"
            );
        } else {
            require(
                listings[tokenId].expirationDate < block.timestamp,
                "Land is already rented"
            );
        }
        // }
        _;
    }
    // modifier to check if caller is the land owner after item is listed in market
    modifier isLandOwner(uint256 _tokenId, address _caller) {
        require(
            listings[_tokenId].owner == _caller,
            "Caller is not land owner"
        );
        _;
    }
    modifier isNotLandOwner(uint256 _tokenId, address _caller) {
        require(
            listings[_tokenId].owner != _caller,
            "Land owner Can not run this transaction"
        );
        _;
    }

    // if land is not listed on market then we should check who is land owner
    modifier isNFTLandOwner(uint256 _tokenId, address _caller) {
        IERC721 land = IERC721(landContract);
        address nftOwner = land.ownerOf(_tokenId);
        require(nftOwner == _caller, "Caller is not land owner");
        _;
    }

    modifier isValidFee(
        uint256 hourlyFee,
        uint256 dailyFee,
        uint256 monthlyFee
    ) {
        require(hourlyFee > 0, "Hourly Fee must be above zero");
        require(dailyFee > 0, "Daily Fee must be above zero");
        require(monthlyFee > 0, "Monthly Fee must be above zero");
        _;
    }

    modifier isValidSingature() {
        // require(signer == signerAddress, "Invalid Singature");
        _;
    }
    modifier isValidRentPayment(uint256 _landId) {
        require(
            msg.value == listings[_landId].monthlyFee,
            "Insufficient balance to pay rent"
        );
        require(
            listings[_landId].isCollateral == true,
            "Invalid Rent contract type"
        );
        require(
            listings[_landId].nextPayment > block.timestamp,
            "Rent duration is expired"
        );
        require(
            listings[_landId].numberOfPayments < listings[_landId].interval,
            "Number of payment is complete"
        );

        // uint256 landId = _landId;

        // bytes32 hashValue = keccak256(
        //     abi.encodePacked(landId, _referral, _nonce)
        // );
        // bytes32 message = ECDSA.toEthSignedMessageHash(hashValue);
        // address signer = ECDSA.recover(message, _signature);
        // require(signer == signerAddress, "Invalid signature");
        _;
    }
    modifier isValidRentSingature(
        uint256 _landId,
        address _referral,
        string memory _nonce,
        bytes calldata _signature
    ) {
        require(usedNonce[_nonce] == false, "Invalid signature");

        uint256 landId = _landId;

        bytes32 hashValue = keccak256(
            abi.encodePacked(landId, _referral, _nonce)
        );
        bytes32 message = ECDSA.toEthSignedMessageHash(hashValue);
        address signer = ECDSA.recover(message, _signature);
        require(signer == signerAddress, "Invalid signature");
        _;
    }

    constructor(
        IERC721 _landContract,
        IRentPaymentHistory _renPayment,
        ITropyverseGoodFactory _goodFactory,
        ITropyverseTicketFactory _ticketFactory
    ) {
        // signerAddress = signer;
        landContract = _landContract;
        rentHistory = _renPayment;
        goodFactory = _goodFactory;
        ticketFactory = _ticketFactory;
    }

    // sale functions
    // function calculateSalesFee(uint256 price) internal returns (uint256) {
    //     IERC721 land = IERC721(landContract);
    //     uint256 balance = land.balanceOf(msg.sender);
    // }

    // if land is already listed for rent, so it is already transfered to marketplace and just set price and onsale = true

    function putOnSale(uint256 tokenId, uint256 price)
        external
        notListedForSale(tokenId)
    {
        require(price > 0, "Sale price must be above zero");
        if (listings[tokenId].listed == true) {
            require(
                msg.sender == listings[tokenId].owner,
                "Caller is not land owner"
            );
            listings[tokenId].salePrice = price;
            listings[tokenId].onSale = true;
        } else {
            IERC721 nft = IERC721(landContract);
            require(
                nft.ownerOf(tokenId) == msg.sender,
                "Caller is not land owner"
            );

            nft.safeTransferFrom(msg.sender, address(this), tokenId);

            listings[tokenId].listed = true;
            listings[tokenId].salePrice = price;
            listings[tokenId].owner = payable(msg.sender);
            listings[tokenId].onSale = true;

            landIds.push(tokenId);
        }

        // transfer market fee to market owner
        // payable(address(owner())).transfer(msg.value);
        emit ItemListedForSale(msg.sender, tokenId, price);
    }

    // only land owner can cancel land on sale
    // land should exist on listings
    // if land is not on rent, remove the land from listings and transfer ownership back to owner
    // if land is on rent, don't remove token from listings, just change status onSale to false and price to 0
    function cancelOnSale(uint256 _tokenId)
        external
        isListed(_tokenId)
        isListedForSale(_tokenId, msg.sender)
        isLandOwner(_tokenId, msg.sender)
    {
        if (listings[_tokenId].onRent == true) {
            listings[_tokenId].onSale = false;
            listings[_tokenId].salePrice = 0;
        } else {
            IERC721 nft = IERC721(landContract);
            nft.transferFrom(address(this), msg.sender, _tokenId);
            delete listings[_tokenId];
        }
        emit SaleCanceled(msg.sender, _tokenId);
    }

    // no discount for resell but need to calculate agent commission
    // if land is on rent just change the owner and change status of onSale to false
    // if land is not on rent, delete item from market and transfer ownershipt to buyer
    function buyLand(uint256 _tokenId)
        external
        payable
        nonReentrant
        isListed(_tokenId)
        isListedForSale(_tokenId, msg.sender)
        isNotLandOwner(_tokenId, msg.sender)
    {
        require(msg.value >= listings[_tokenId].salePrice, "Invalid price");
        address payable _owner = payable(listings[_tokenId].owner);
        uint256 ownerFee = calculateSaleFee(msg.value, _owner);
        uint256 makretFee = msg.value - ownerFee;
        uint256 landId = _tokenId;
        (bool sentOwnerFee, ) = payable(_owner).call{value: ownerFee}("");
        require(sentOwnerFee, "Failed to send Ether");
        (bool sentMarketFee, ) = payable(_owner).call{value: makretFee}("");
        require(sentMarketFee, "Failed to send Ether");

        // if it is on rent, leave tenant with the list of goods, else delete all items
        (bool hasTenant, ) = getLandResident(landId);
        if (hasTenant == true) {
            listings[landId].onSale = false;
            listings[landId].salePrice = 0;
            listings[landId].previousOwner = _owner;
            listings[landId].owner = msg.sender;
        } else {
            IERC721 nft = IERC721(landContract);
            nft.safeTransferFrom(address(this), msg.sender, landId);
            delete listings[landId];
            detachAssets(landId, 1, msg.sender);
        }

        emit LandBought(
            msg.sender,
            hasTenant,
            landId,
            listings[landId].salePrice
        );
    }

    function detachAssets(
        uint256 _tokenId,
        uint256 _reason,
        address _remover
    ) internal {
        ITropyverseGoodFactory(goodFactory).detachLandGoods(
            _tokenId,
            _reason,
            _remover
        );
        ITropyverseTicketFactory(ticketFactory).detachEducationTickets(
            _tokenId,
            _reason,
            _remover
        );
        ITropyverseTicketFactory(ticketFactory).detachEventTickets(
            _tokenId,
            _reason,
            _remover
        );
    }

    // function is checked
    function updateSalePrice(uint256 _tokenId, uint256 _newPrice)
        external
        nonReentrant
        isListed(_tokenId)
        isListedForSale(_tokenId, msg.sender)
        isLandOwner(_tokenId, msg.sender)
    {
        require(_newPrice > 0, "New Price must be above zero");

        listings[_tokenId].salePrice = _newPrice;

        emit ItemUpdatedForSale(msg.sender, _tokenId, _newPrice);
    }

    // check not listed for rent
    // check not rented by tenant
    // if already listed, update rent fields
    // if not listed, transfer to marketplace, then change rent fields
    function putOnRent(
        uint256 tokenId,
        uint256 hourlyFee,
        uint256 dailyFee,
        uint256 monthlyFee
    )
        external
        notListedForRent(tokenId)
        notRented(tokenId)
        isValidFee(hourlyFee, dailyFee, monthlyFee)
    {
        // it is already transfered so no need to transfer it to marketplace
        if (listings[tokenId].listed == true) {
            require(
                listings[tokenId].owner == msg.sender,
                "Caller is not land owner"
            );
            listings[tokenId].numberOfPayments = 0;
            listings[tokenId].hourlyFee = hourlyFee;
            listings[tokenId].dailyFee = dailyFee;
            listings[tokenId].monthlyFee = monthlyFee;
            listings[tokenId].interval = 0;
            listings[tokenId].startDate = 0;
            listings[tokenId].expirationDate = 0;
            listings[tokenId].nextPayment = 0;
            listings[tokenId].expired = 0;
            listings[tokenId].tenant = address(0);
            listings[tokenId].isCollateral = false;
            listings[tokenId].onRent = true;
        } else {
            IERC721 nft = IERC721(landContract);
            require(
                nft.ownerOf(tokenId) == msg.sender,
                "Caller is not land owner"
            );

            nft.safeTransferFrom(msg.sender, address(this), tokenId);

            listings[tokenId].listed = true;
            listings[tokenId].numberOfPayments = 0;
            listings[tokenId].salePrice = 0;
            listings[tokenId].hourlyFee = hourlyFee;
            listings[tokenId].dailyFee = dailyFee;
            listings[tokenId].monthlyFee = monthlyFee;
            listings[tokenId].selectedRentType = 0;
            listings[tokenId].interval = 0;
            listings[tokenId].startDate = 0;
            listings[tokenId].expirationDate = 0;
            listings[tokenId].nextPayment = 0;
            listings[tokenId].expired = 0;
            listings[tokenId].previousOwner = payable(address(0));
            listings[tokenId].owner = payable(msg.sender);
            listings[tokenId].tenant = address(0);
            listings[tokenId].onRent = true;
            listings[tokenId].isCollateral = false;

            landIds.push(tokenId);
        }

        emit LandListedForRent(
            msg.sender,
            tokenId,
            hourlyFee,
            dailyFee,
            monthlyFee
        );
    }

    function updateLandOnRent(
        uint256 tokenId,
        uint256 hourlyFee,
        uint256 dailyFee,
        uint256 monthlyFee
    )
        external
        isListed(tokenId)
        isListedForRent(tokenId)
        isLandOwner(tokenId, msg.sender)
        notRented(tokenId)
        isValidFee(hourlyFee, dailyFee, monthlyFee)
    {
        require(
            listings[tokenId].owner == msg.sender,
            "Caller is not land owner"
        );
        listings[tokenId].numberOfPayments = 0;
        listings[tokenId].hourlyFee = hourlyFee;
        listings[tokenId].dailyFee = dailyFee;
        listings[tokenId].monthlyFee = monthlyFee;
        listings[tokenId].interval = 0;
        listings[tokenId].startDate = 0;
        listings[tokenId].expirationDate = 0;
        listings[tokenId].nextPayment = 0;
        listings[tokenId].expired = 0;
        listings[tokenId].tenant = address(0);
        listings[tokenId].isCollateral = false;
        listings[tokenId].onRent = true;

        emit LandUpdatedForRent(
            listings[tokenId].owner,
            tokenId,
            hourlyFee,
            dailyFee,
            monthlyFee
        );
    }

    // no refund and land owner can cancel when land is not rented by tenant
    // check if land is listed in marketplace
    // land should be listed for rent
    // caller should be the land owner
    // land should not be on rent
    function cancelOnRent(uint256 _tokenId)
        external
        isListed(_tokenId)
        isListedForRent(_tokenId)
        isLandOwner(_tokenId, msg.sender)
        notRented(_tokenId)
    {
        if (listings[_tokenId].onSale == true) {
            listings[_tokenId].hourlyFee = 0;
            listings[_tokenId].dailyFee = 0;
            listings[_tokenId].monthlyFee = 0;
            listings[_tokenId].interval = 0;
            listings[_tokenId].startDate = 0;
            listings[_tokenId].expirationDate = 0;
            listings[_tokenId].nextPayment = 0;
            listings[_tokenId].expired = 0;
            listings[_tokenId].tenant = address(0);
            listings[_tokenId].onRent = false;
            listings[_tokenId].isCollateral = false;
        } else {
            IERC721 nft = IERC721(landContract);
            nft.safeTransferFrom(address(this), msg.sender, _tokenId);
            delete listings[_tokenId];
        }

        emit LandRemovedFromRent(msg.sender, _tokenId);
    }

    // tenant can cancel rent on contract
    function cancelRentAsTenant(uint256 _tokenId)
        external
        isListed(_tokenId)
        isListedForRent(_tokenId)
        isRented(_tokenId)
        isTenant(msg.sender, _tokenId)
    {
        listings[_tokenId].interval = 0;
        listings[_tokenId].startDate = 0;
        listings[_tokenId].expirationDate = 0;
        listings[_tokenId].nextPayment = 0;
        listings[_tokenId].expired = 3;
        listings[_tokenId].tenant = address(0);
        listings[_tokenId].isCollateral = false;
        emit RentCanceledTenant(msg.sender, _tokenId);
        detachAssets(_tokenId, 3, msg.sender);
    }

    // if selected rent type is morethan 2 months, next payment is start date + 30 days
    // land should be listed for rent
    // land should not be on rent by other tenant
    function rentLand(
        uint256 _tokenId,
        uint256 rentType,
        uint256 interval,
        string memory _email
    )
        external
        payable
        nonReentrant
        isListedForRent(_tokenId)
        notRented(_tokenId)
        isNotLandOwner(_tokenId, msg.sender)
    {
        uint256 id = _tokenId;

        uint256 rentalFee = calculateRentFee(rentType, interval, id);
        require(msg.value == rentalFee, "Insufficient balance to rent");
        address landOwner = payable(listings[id].owner);

        MarketItem memory land = listings[id];
        land.tenant = msg.sender;

        // expiration date is calculated by interval * selected rent type hours, days, month
        (
            uint256 startDate,
            uint256 expirationDate,
            bool isCollateral
        ) = calculateExpirationTime(rentType, interval);
        // start date of renting land

        if (isCollateral == true) {
            land.numberOfPayments = 2;
            land.nextPayment = startDate + 30 days;
            land.isCollateral = true;
        } else {
            land.numberOfPayments = 1;
            land.nextPayment = 0;
            land.isCollateral = false;
        }
        land.interval = interval;
        land.selectedRentType = rentType;
        land.startDate = startDate;
        land.expirationDate = expirationDate;
        listings[id] = land;

        // transfer balance to parties
        transferRentFund(isCollateral, address(0), landOwner, rentalFee);

        // record the payment of rent
        handleRentHistory(
            msg.sender,
            landOwner,
            isCollateral,
            id,
            msg.value,
            startDate,
            expirationDate
        );

        //  emit event LandRented
        handleRentLand(id, address(0), msg.value, _email, listings[id]);
        detachAssets(id, 2, msg.sender);
    }

    function rentLandReferral(
        uint256 _tokenId,
        uint256 _rentType,
        uint256 interval,
        address _referral,
        string memory _email,
        string memory _nonce,
        bytes calldata _signature
    )
        external
        payable
        nonReentrant
        isListedForRent(_tokenId)
        notRented(_tokenId)
        isNotLandOwner(_tokenId, msg.sender)
        isValidRentPayment(_tokenId)
        isValidRentSingature(_tokenId, _referral, _nonce, _signature)
    {
        // uint256 id = _tokenId;
        // rent fee for renting land is calculated by interval * interval fee
        // uint256 rentalFee = calculateRentFee(_rentType, interval, id);
        // require(msg.value == rentalFee, "Insufficient balance to rent");
        // address landOwner = payable(listings[id].owner);
        // MarketItem memory land = listings[id];
        // land.tenant = msg.sender;
        // // expiration date is calculated by interval * selected rent type hours, days, month
        // (
        //     uint256 startDate,
        //     uint256 expirationDate,
        //     bool isCollateral
        // ) = calculateExpirationTime(_rentType, interval);
        // // start date of renting land
        // if (isCollateral == true) {
        //     land.numberOfPayments = 2;
        //     land.nextPayment = startDate + 30 days;
        //     land.isCollateral = true;
        // } else {
        //     land.numberOfPayments = 1;
        //     land.nextPayment = 0;
        //     land.isCollateral = false;
        // }
        // land.interval = interval;
        // land.selectedRentType = _rentType;
        // land.startDate = startDate;
        // land.expirationDate = expirationDate;
        // listings[id] = land;
        // // transfer balance to parties
        // transferRentFund(isCollateral, _referral, landOwner, rentalFee);
        // // record the payment of rent
        // handleRentHistory(
        //     msg.sender,
        //     landOwner,
        //     isCollateral,
        //     id,
        //     msg.value,
        //     startDate,
        //     expirationDate
        // );
        // //  emit event LandRented
        // handleRentLand(id, _referral, msg.value, _email, listings[id]);
        // detachAssets(id, 2, msg.sender);
        // usedNonce[_nonce] = true;
    }

    // internal functions
    //payment for renting land if referral 10 percent goes to agent and 10 percent to marketplace
    // if no referral, then 25 percent goes to marketplace owner

    function verifyRentSignature(
        uint256 _landId,
        address _referral,
        string memory _nonce,
        bytes calldata _signature
    ) internal view returns (bool) {
        require(!usedNonce[_nonce], "Invalid Signature");

        bytes32 hashValue = keccak256(
            abi.encodePacked(_landId, _referral, _nonce)
        );
        bytes32 message = ECDSA.toEthSignedMessageHash(hashValue);
        address signer = ECDSA.recover(message, _signature);
        require(
            signer != address(0) && signer == signerAddress,
            "Invalid Signature"
        );
        return signer == signerAddress;
    }

    // this internal function is used to transfer rental contract funds to market owner, agent and land owner
    function transferRentFund(
        bool isCollateral,
        address referral,
        address landOwner,
        uint256 rentalFee
    ) internal {
        uint256 marketFee = (rentalFee * rentServiceFee) / 100;

        uint256 agentFee = (rentalFee * agentRentcommission) / 100;

        uint256 ownerFee = msg.value - marketFee;

        if (isCollateral == true && referral != address(0)) {
            //agent fee is subtracted from market fee if referral
            marketFee = marketFee - agentFee;

            // market fee is calculated like this
            (bool sentMarketFee, ) = payable(owner()).call{value: marketFee}(
                ""
            );
            require(sentMarketFee, "Failed to send Ether");

            (bool sentAgentFee, ) = payable(referral).call{value: agentFee}("");
            require(sentAgentFee, "Failed to send Ether");

            (bool sentOwnerFee, ) = payable(landOwner).call{value: ownerFee}(
                ""
            );
            require(sentOwnerFee, "Failed to send Ether");
        } else {
            (bool sentMarketFee, ) = payable(owner()).call{value: marketFee}(
                ""
            );
            require(sentMarketFee, "Failed to send Ether");

            (bool sentOwnerFee, ) = payable(landOwner).call{
                value: rentalFee - marketFee
            }("");
            require(sentOwnerFee, "Failed to send Ether");
        }
    }

    // helper function for storing payment history in payment contract
    function handleRentHistory(
        address _sender,
        address _receiver,
        bool _rentType,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _start,
        uint256 _expiration
    ) internal {
        rentHistory.payRent(
            _sender,
            _receiver,
            _rentType,
            _tokenId,
            _amount,
            _start,
            _expiration
        );
    }

    // helper function for emiting land item is rented
    function handleRentLand(
        uint256 tokenId,
        address agent,
        uint256 amount,
        string memory email,
        MarketItem memory item
    ) internal {
        emit LandRented(
            item.selectedRentType,
            item.interval,
            tokenId,
            amount,
            item.startDate,
            item.expirationDate,
            item.nextPayment,
            item.owner,
            item.tenant,
            agent,
            email,
            item.isCollateral
        );
    }

    // check if sender is tenant
    // check if rent is not expired
    // check number of payment is not complete

    function handleNextPayment(uint256 _tokenId)
        external
        payable
        isListed(_tokenId)
        isRented(_tokenId)
        isTenant(msg.sender, _tokenId)
    {
        require(
            msg.value == listings[_tokenId].monthlyFee,
            "Insufficient balance to pay rent"
        );
        require(
            listings[_tokenId].isCollateral == true,
            "Invalid Rent contract type"
        );
        require(
            listings[_tokenId].expirationDate > block.timestamp,
            "Rent duration is expired"
        );
        require(
            listings[_tokenId].numberOfPayments < listings[_tokenId].interval,
            "Number of payment is complete"
        );
        listings[_tokenId].nextPayment =
            listings[_tokenId].nextPayment +
            30 days;
        listings[_tokenId].numberOfPayments =
            listings[_tokenId].numberOfPayments +
            1;

        rentHistory.payRent(
            msg.sender,
            listings[_tokenId].owner,
            true,
            _tokenId,
            msg.value,
            listings[_tokenId].startDate,
            listings[_tokenId].expirationDate
        );
    }

    function handleNextPayment(
        uint256 _tokenId,
        address _referral,
        string memory _nonce,
        bytes calldata _signature
    )
        external
        payable
        isValidRentPayment(_tokenId)
        isValidRentSingature(_tokenId, _referral, _nonce, _signature)
    {
        uint256 landId = _tokenId;
        address referral = _referral;
        string memory nonce = _nonce;
        transferRentFund(true, referral, listings[landId].owner, msg.value);
        listings[landId].nextPayment = listings[landId].nextPayment + 30 days;
        listings[landId].numberOfPayments =
            listings[landId].numberOfPayments +
            1;

        rentHistory.payRent(
            msg.sender,
            listings[landId].owner,
            true,
            landId,
            msg.value,
            listings[landId].startDate,
            listings[landId].expirationDate
        );

        usedNonce[nonce] = true;
    }

    // function return expiration date of token
    function getExpirationDate(uint256 _tokenId)
        external
        view
        isListed(_tokenId)
        returns (uint256 startDate, uint256 expiration)
    {
        return (
            listings[_tokenId].startDate,
            listings[_tokenId].expirationDate
        );
    }

    function withdrawBalance(address payable _to, uint256 amount)
        external
        onlyOwner
        returns (bool, bytes memory)
    {
        require((amount <= address(this).balance), "insufficient balance");
        (bool sent, bytes memory data) = _to.call{value: amount}("");
        require(sent, "Failed to send Ether");
        return (sent, data);
    }

    function getLandDetails(uint256 _tokenId)
        external
        view
        returns (MarketItem memory item)
    {
        if (listings[_tokenId].listed == true) {
            return listings[_tokenId];
        } else {
            return
                MarketItem(
                    false,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    payable(address(0)),
                    IERC721(landContract).ownerOf(_tokenId),
                    address(0),
                    false,
                    false,
                    false
                );
        }
    }

    // 1 hourly, 2 daily,  3 monthly
    // if rentType is 3 we get 2 months, isCollateral true it is count as secure deposit otherwise it is total rent
    function calculateRentFee(
        uint256 rentType,
        uint256 interval,
        uint256 tokenId
    ) internal view returns (uint256 ownerFee) {
        require(rentType > 0 && rentType < 4, "Invalid rent type");

        if (rentType == 1) {
            return listings[tokenId].hourlyFee * interval;
        }
        if (rentType == 2) {
            return listings[tokenId].dailyFee * interval;
        }

        if (rentType == 3 && interval < 3) {
            return listings[tokenId].monthlyFee * interval;
        }
        if (rentType == 3 && interval >= 3) {
            return listings[tokenId].monthlyFee * 2;
        }
    }

    //tested function
    // this function will calculate and return expiration time and isCollateral
    // 1 hourly, 2 daily,  3 monthly
    function calculateExpirationTime(uint256 rentType, uint256 interval)
        internal
        view
        returns (
            uint256 startDate,
            uint256 expirationTime,
            bool isCollateral
        )
    {
        require(rentType > 0 && rentType < 4, "Invalid rent type");

        if (rentType == 1) {
            return (
                block.timestamp,
                block.timestamp + (interval * 60 minutes),
                false
            );
        }
        if (rentType == 2) {
            return (
                block.timestamp,
                block.timestamp + (interval * 1 days),
                false
            );
        }
        if (rentType == 3) {
            if (interval < 3) {
                return (
                    block.timestamp,
                    block.timestamp + (interval * 30 days),
                    false
                );
            } else {
                return (
                    block.timestamp,
                    block.timestamp + (interval * 30 days),
                    true
                );
            }
        }
        return (0, 0, false);
    }

    // this function is used to return who has access to currently to land
    // return true  and owner wallet if land is not rented or expired, otherwise false and tenant wallet
    function getLandResident(uint256 _landId)
        internal
        view
        returns (bool hasTenat, address operator)
    {
        if (listings[_landId].tenant != address(0)) {
            if (listings[_landId].isCollateral == true) {
                if (listings[_landId].nextPayment + 30 days > block.timestamp) {
                    return (true, listings[_landId].tenant);
                } else {
                    return (false, listings[_landId].owner);
                }
            } else {
                if (listings[_landId].expirationDate > block.timestamp) {
                    return (true, listings[_landId].tenant);
                } else {
                    return (false, listings[_landId].owner);
                }
            }
        } else {
            return (false, listings[_landId].owner);
        }
    }

    // for creating good items, we need to check if  caller has access to land or not,
    // 3 possible situation
    // 1- land is minted and we check the land ower from land contract
    // 2- land is listed on market and listed on sale or on rent
    // 3- land is rented and contract is not expired
    function checkLandOperator(uint256 _landId)
        external
        view
        returns (address operator)
    {
        if (listings[_landId].listed == true) {
            if (listings[_landId].tenant != address(0)) {
                if (listings[_landId].isCollateral == true) {
                    if (
                        listings[_landId].nextPayment + 30 days >
                        block.timestamp
                    ) {
                        return listings[_landId].tenant;
                    } else {
                        return listings[_landId].owner;
                    }
                } else {
                    if (listings[_landId].expirationDate > block.timestamp) {
                        listings[_landId].tenant;
                    } else {
                        return listings[_landId].owner;
                    }
                }
            } else {
                return listings[_landId].owner;
            }
        } else {
            return landContract.ownerOf(_landId);
        }
    }

    function calculateSaleFee(uint256 amount, address _owner)
        internal
        view
        returns (uint256)
    {
        uint256 lands = getTotalLands(_owner);

        if (lands > 10) {
            return amount - (amount * (saleServiceFee - 5)) / 100;
        }
        if (lands > 5) {
            return amount - (amount * (saleServiceFee - 2)) / 100;
        }
        return amount - (amount * (saleServiceFee)) / 100;
    }

    function getSaleServiceFee() external view returns (uint256 fee) {
        return saleServiceFee;
    }

    function setSaleServiceFee(uint256 newFee)
        external
        onlyOwner
        returns (uint256 fee)
    {
        require(newFee > 1 && newFee < 20, "Invalid service fee");
        saleServiceFee = newFee;
        return saleServiceFee;
    }

    // helper function to set agent commission for marketplace
    function setAgentRentCommission(uint256 commission) external onlyOwner {
        require(commission > 1 && commission <= 20, "Invalid commission value");
        require(commission != agentRentcommission, "Invalid commission value");
        agentRentcommission = commission;
    }

    // override functions
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

    // check if land is on rent
    // setting functions for contracts
    // set land nft contract
    function setLandContract(IERC721 _land)
        external
        onlyOwner
        returns (address newLandContract)
    {
        require(
            address(landContract) != address(_land),
            "Trying to set invalid contract address"
        );
        landContract = _land;
        return address(_land);
    }

    // get land nft contract
    function getLandContract() external view returns (address land) {
        return address(landContract);
    }

    function setRenContract(IERC721 _land)
        external
        onlyOwner
        returns (address newLandContract)
    {
        require(
            address(landContract) != address(_land),
            "Trying to set invalid contract address"
        );
        landContract = _land;
        return address(_land);
    }

    // get land nft contract
    function getRentContract() external view returns (address land) {
        return address(landContract);
    }

    // set good factory contract address
    function setGoodFactory(ITropyverseGoodFactory factory)
        external
        onlyOwner
        returns (address newFoodFactory)
    {
        require(
            factory != goodFactory,
            "Trying to set invalid contract address"
        );
        goodFactory = factory;
        return address(factory);
    }

    function getGoodFactory() external view returns (address factory) {
        return address(goodFactory);
    }

    function setTicketFactory(ITropyverseTicketFactory factory)
        external
        onlyOwner
    {
        ticketFactory = factory;
    }

    function getTicketFactory() external view returns (address factory) {
        return address(ticketFactory);
    }

    // external function to check if item is already listed so dont ask about approve token
    function isItemListed(uint256 _landId) external view returns (bool listed) {
        if (listings[_landId].listed == true) {
            return true;
        } else {
            return false;
        }
    }

    function getTotalLands(address _wallet)
        public
        view
        returns (uint256 lands)
    {
        uint256 counter = 0;
        for (uint256 i = 0; i < landIds.length; i++) {
            if (
                listings[landIds[i]].listed == true &&
                listings[landIds[i]].owner == _wallet
            ) {
                counter++;
            }
        }

        return counter + IERC721(landContract).balanceOf(_wallet);
    }

    function transferLand(uint256 _tokenId, address _to)
        external
        isListed(_tokenId)
        onlyOwner
    {
        require(
            _to == listings[_tokenId].owner || _to == listings[_tokenId].tenant,
            "Invalid address to transfer land"
        );
        IERC721 nft = IERC721(landContract);
        nft.safeTransferFrom(address(this), _to, _tokenId);
        delete listings[_tokenId];
        detachAssets(_tokenId, 4, msg.sender);
    }
}
