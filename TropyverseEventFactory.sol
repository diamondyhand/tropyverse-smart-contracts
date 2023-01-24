//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/ITropyverseTicket.sol";
import "./TropyverseEventTicket.sol";
import "./TropyverseStructure.sol";

contract TropyverseEventFactory is Ownable {
    mapping(uint256 => address[]) private eventContracts;

    address marketContract;

    uint256 marketFee = 5;
    uint256 eventCounter = 0;

    event TicketBought(
        address indexed owner,
        address indexed buyer,
        TropyverseStructure.Ticket ticket
    );

    event TicketCreated(
        address indexed owner,
        address indexed contractAddress,
        string[] details,
        TropyverseStructure.TicketFeatures features,
        uint256 index
    );
    event TicketsDetached(
        uint256 landId,
        uint256 reason,
        address indexed remover
    );

    event MarketFeeUpdated(uint256 price);

    event EventTicketRemoved(
        uint256 landId,
        uint256 eventId,
        address contractAddress,
        address remover
    );

    event PriceUpdated(
        uint256 landId,
        uint256 index,
        uint256 tokenType,
        uint256 newPrice,
        address indexed contractAddress
    );

    modifier onlyAuthorized() {
        require(
            msg.sender == marketContract || msg.sender == owner(),
            "NOT_AUTHORIZED"
        );
        _;
    }
    modifier onlyEventOwner(uint256 _landId, uint256 _index) {
        require(
            msg.sender ==
                ITropyverseTicket(eventContracts[_landId][_index]).getOwner(),
            "NOT_AUTHORIZED"
        );
        _;
    }

    function addEventCollection(
        string[] calldata _details,
        TropyverseStructure.TicketFeatures calldata _features
    ) external returns (uint256 length) {
        uint256 landId = _features.landId;
        address author = ITropyverseMarket(marketContract).checkLandOperator(
            landId
        );
        require(msg.sender == author, "NOT_AUTHORIZED");

        TropyverseEventTicket ticket = new TropyverseEventTicket(
            _details,
            _features,
            address(this)
        );
        ITropyverseTicket(address(ticket)).setOwner(msg.sender);

        eventContracts[landId].push(address(ticket));
        eventCounter++;

        uint256 index = eventContracts[landId].length - 1;
        emit TicketCreated(
            msg.sender,
            address(ticket),
            _details,
            _features,
            // _startDate,
            // _durations,
            // _vipSupply,
            // _standardSupply,
            // _vipPrice,
            // _standardPrice,
            // _landId,
            index
        );
        return index;
    }

    function buyEventTicket(
        address _collection,
        uint256 _landId,
        uint256 _type
    ) external payable {
        require(
            msg.value == ITropyverseTicket(_collection).getPrice(_type),
            "Price not met"
        );
        handleEthTransfer(msg.value, _collection);
        uint256 marketCut = (msg.value * marketFee) / 100;
        uint256 ownerCut = msg.value - marketCut;

        uint256 _tokenId = ITropyverseTicket(_collection).buy(
            msg.sender,
            _type
        );
        emit TicketBought(
            ITropyverseTicket(_collection).getOwner(),
            msg.sender,
            TropyverseStructure.Ticket(
                _collection,
                _tokenId,
                _type,
                msg.value,
                _landId,
                marketCut,
                ownerCut
            )
        );
    }

    function getLandEvents(
        uint256 _landId
    ) external view returns (address[] memory _collections) {
        return eventContracts[_landId];
    }

    // delete item from items

    function deleteEvent(
        uint256 _landId,
        uint256 _itemIndex
    ) external onlyEventOwner(_landId, _itemIndex) {
        eventContracts[_landId][_itemIndex] = eventContracts[_landId][
            eventContracts[_landId].length - 1
        ];

        eventContracts[_landId].pop();
        eventCounter--;
        emit EventTicketRemoved(
            _landId,
            _itemIndex,
            eventContracts[_landId][_itemIndex],
            msg.sender
        );
    }

    function getLandTickets(
        uint256 landId
    ) external view returns (address[] memory myItems) {
        return eventContracts[landId];
    }

    // remove listing from market
    // 1- item is bought by new owner
    // 2- item is rent by tenant
    // 3- tenant canceled the rent contract

    function detachTickets(
        uint256 _landId,
        uint256 reason,
        address remover
    ) external onlyAuthorized {
        if (eventContracts[_landId].length > 0) {
            uint256 counter = eventContracts[_landId].length;
            delete eventContracts[_landId];
            eventCounter = eventCounter - counter;
        }
        emit TicketsDetached(_landId, reason, remover);
    }

    function setMarketFee(uint256 _fee) external onlyOwner {
        require(_fee > 0 && _fee != marketFee, "Invalid marekt fee");

        marketFee = _fee;
        emit MarketFeeUpdated(marketFee);
    }

    function getMarketFee() external view returns (uint256 fee) {
        return marketFee;
    }

    function setMarketContract(address market) external onlyOwner {
        marketContract = market;
    }

    function getMarketContract()
        external
        view
        returns (address contractAddress)
    {
        return marketContract;
    }

    function getOwner() external view returns (address marketOwner) {
        return owner();
    }

    function setOwner(address _newOwner) external onlyOwner {
        transferOwnership(_newOwner);
    }

    function getTicketOwner(
        address contractAddress
    ) external view returns (address _collectionOwner) {
        return ITropyverseTicket(contractAddress).getOwner();
    }

    function setPrice(
        uint256 _landId,
        uint256 _index,
        uint256 _tokenType,
        uint256 _newPrice
    ) external onlyEventOwner(_landId, _index) {
        address contractAddress = eventContracts[_landId][_index];
        ITropyverseTicket(contractAddress).setPrice(_tokenType, _newPrice);

        emit PriceUpdated(
            _landId,
            _index,
            _tokenType,
            _newPrice,
            contractAddress
        );
    }

    /// internal functions

    function handleEthTransfer(
        uint256 _price,
        address _contract
    ) internal returns (uint256 _marketCut, uint256 _ownerCut) {
        uint256 mFee = (_price * marketFee) / 100;
        uint256 ownerFee = _price - mFee;

        (bool sentMarketFee, ) = payable(owner()).call{value: mFee}("");
        require(sentMarketFee, SEND_PRICE_ERROR);

        (bool sentOwnerFee, ) = payable(ITropyverseTicket(_contract).getOwner())
            .call{value: ownerFee}("");
        require(sentOwnerFee, SEND_PRICE_ERROR);

        return (mFee, ownerFee);
    }
}
