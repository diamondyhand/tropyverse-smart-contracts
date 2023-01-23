//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/ITropyverseTicket.sol";
import "./TropyverseEducationTicket.sol";
import "./TropyverseStructure.sol";

contract TropyverseEducationFactory is Ownable {
    mapping(uint256 => address[]) private educationContracts;

    address marketContract;

    uint256 marketFee = 5;
    uint256 educationCounter = 0;
    //education ticket events
    event TicketCreated(
        address indexed owner,
        address indexed contractAddress,
        string[] details,
        TropyverseStructure.TicketFeatures features,
        uint256 index
    );

    event TicketBought(
        address indexed owner,
        address indexed buyer,
        TropyverseStructure.Ticket ticket
    );
    event TicketsRemoved(
        uint256 landId,
        uint256 educationId,
        address contractAddress,
        address remover
    );
    event TicketsDetached(
        uint256 landId,
        uint256 reason,
        address indexed remover
    );
    event PriceUpdated(
        uint256 landId,
        uint256 index,
        uint256 tokenType,
        uint256 newPrice,
        address indexed contractAddress
    );

    event MarketFeeUpdated(uint256 price);

    modifier onlyAuthorized() {
        require(
            msg.sender == marketContract || msg.sender == owner(),
            "NOT_AUTHORIZED"
        );
        _;
    }
    modifier onlyTicketOwner(uint256 _landId, uint256 _index) {
        require(
            msg.sender ==
                ITropyverseTicket(educationContracts[_landId][_index])
                    .getOwner(),
            "NOT_AUTHORIZED"
        );
        _;
    }

    function addCollection(
        string[] memory _details,
        TropyverseStructure.TicketFeatures memory _features
    ) external {
        uint256 landId = _features.landId;
        address author = ITropyverseMarket(marketContract).checkLandOperator(
            landId
        );
        require(msg.sender == author, "NOT_AUTHORIZED");

        TropyverseEducationTicket education = new TropyverseEducationTicket(
            _details,
            _features,
            address(this)
        );
        ITropyverseTicket(address(education)).setOwner(msg.sender);

        educationContracts[landId].push(address(education));
        educationCounter++;

        uint256 index = educationContracts[landId].length - 1;

        emit TicketCreated(
            msg.sender,
            address(education),
            _details,
            _features,
            index
        );
    }

    function buyTicket(
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

    function getLandTickets(
        uint256 _landId
    ) external view returns (address[] memory _collections) {
        return educationContracts[_landId];
    }

    function deleteTicket(
        uint256 _landId,
        uint256 _itemIndex
    ) external onlyTicketOwner(_landId, _itemIndex) {
        educationContracts[_landId][_itemIndex] = educationContracts[_landId][
            educationContracts[_landId].length - 1
        ];

        educationContracts[_landId].pop();
        educationCounter--;

        emit TicketsRemoved(
            _landId,
            _itemIndex,
            educationContracts[_landId][_itemIndex],
            msg.sender
        );
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
        if (educationContracts[_landId].length > 0) {
            uint256 counter = educationContracts[_landId].length;
            delete educationContracts[_landId];
            educationCounter = educationCounter - counter;
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
    ) external onlyTicketOwner(_landId, _index) {
        address contractAddress = educationContracts[_landId][_index];
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

    function handleEthTransfer(uint256 _price, address _contract) internal {
        uint256 mFee = (_price * marketFee) / 100;
        uint256 ownerFee = _price - mFee;

        (bool sentMarketFee, ) = payable(owner()).call{value: mFee}("");
        require(sentMarketFee, "INVALID_SEND_PRICE");

        (bool sentOwnerFee, ) = payable(ITropyverseTicket(_contract).getOwner())
            .call{value: ownerFee}("");
        require(sentOwnerFee, "INVALID_SEND_PRICE");
    }
}
