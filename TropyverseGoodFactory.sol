//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/ITropyverseMarket.sol";
import "./interface/ITropyverseGood.sol";
import "./TropyverseGood.sol";
import "hardhat/console.sol";

contract TropyverseGoodFactory is Ownable {
    uint256 private goodCounter;
    mapping(uint256 => address[]) private goodContracts;

    // mapping(uint256 => GoodItem[]) private items;
    uint256[] landIds;
    uint256 marketFee = 5;
    // events

    event GoodItemCreated(
        address indexed owner,
        address indexed contractAddress,
        string[] details,
        uint256 totalSupply,
        uint256 price,
        uint256 landId,
        uint256 index
    );
    event GoodsDetached(
        address indexed owner,
        address indexed contractAddress,
        address indexed remover,
        uint256 landId,
        uint256 reason
    );

    event GoodTicketRemoved(
        uint256 landId,
        uint256 goodId,
        address contractAddress,
        address remover
    );

    event GoodItemUpdated(
        address indexed contractAddress,
        address indexed owner,
        uint256 newPrice,
        uint256 landId,
        uint256 itemId
    );

    event GoodItemBought(
        address indexed owner,
        address indexed buyer,
        address indexed contractAddress,
        string[] details,
        uint256 tokenId,
        uint256 price,
        uint256 landId,
        uint256 marketCommission,
        uint256 ownerCommission
    );
    enum ItemStatus {
        Available,
        Purchased,
        Unavailable
    }

    struct GoodItem {
        address owner;
        address contractAddress;
        uint256 landId;
        uint256 totalSupply;
        uint256 totalSold;
        uint256 price;
        string name;
        string symbol;
        string tokenUri;
        string fbxUri;
        string category;
        string description;
        ItemStatus itemStatus;
    }
    address marketContract;

    modifier onlyMarketContract() {
        require(msg.sender == marketContract, "NOT_AUTHORIZED");
        _;
    }
    modifier onlyAuthorized() {
        require(
            msg.sender == marketContract || msg.sender == owner(),
            "NOT_AUTHORIZED"
        );
        _;
    }
    modifier onlyGoodOwner(uint256 _landId, uint256 _index) {
        require(
            msg.sender ==
                ITropyverseGood(goodContracts[_landId][_index]).getOwner(),
            "NOT_OWNER"
        );
        _;
    }

    function addGoodCollection(
        string[] memory _details,
        uint256 _landId,
        uint256 _totalSupply,
        uint256 _price
    ) external returns (uint256 _index) {
        address author = ITropyverseMarket(marketContract).checkLandOperator(
            _landId
        );
        require(msg.sender == author, "NOT_AUTHORIZED");

        TropyverseGood good = new TropyverseGood(
            _details,
            _landId,
            _totalSupply,
            _price,
            address(this)
        );

        ITropyverseGood(address(good)).setOwner(msg.sender);
        goodContracts[_landId].push(address(good));
        uint256 index = goodContracts[_landId].length - 1;
        emit GoodItemCreated(
            msg.sender,
            address(good),
            _details,
            _totalSupply,
            _price,
            _landId,
            index
        );
        return index;
    }

    function buyGood(address _collection) external payable {
        require(
            msg.value == ITropyverseGood(_collection).getPrice(),
            "Price not met"
        );
        (uint256 marketCut, uint256 ownerCut) = handleEthTransfer(
            msg.value,
            _collection
        );
        (
            address owner,
            address collection,
            string[] memory _details,
            uint256 _tokenId,
            uint256 _price,
            uint256 _landId
        ) = ITropyverseGood(_collection).buy(msg.sender);
        emit GoodItemBought(
            owner,
            msg.sender,
            collection,
            _details,
            _tokenId,
            _price,
            _landId,
            marketCut,
            ownerCut
        );
    }

    function handleEthTransfer(
        uint256 _price,
        address _contract
    ) internal returns (uint256 marketCut, uint256 ownerCut) {
        uint256 mFee = (_price * marketFee) / 100;
        uint256 ownerFee = _price - mFee;

        (bool sentMarketFee, ) = payable(owner()).call{value: mFee}("");
        require(sentMarketFee, SEND_PRICE_ERROR);

        (bool sentOwnerFee, ) = payable(ITropyverseGood(_contract).getOwner())
            .call{value: ownerFee}("");
        require(sentOwnerFee, SEND_PRICE_ERROR);
        return (mFee, ownerFee);
    }

    function getLandGoods(
        uint256 _landId
    ) external view returns (address[] memory _goodContracts) {
        return goodContracts[_landId];
    }

    function deleteGoodContract(
        uint256 _landId,
        uint256 _itemIndex
    ) external onlyGoodOwner(_landId, _itemIndex) {
        goodContracts[_landId][_itemIndex] = goodContracts[_landId][
            goodContracts[_landId].length - 1
        ];

        goodContracts[_landId].pop();
        goodCounter--;
        emit GoodTicketRemoved(
            _landId,
            _itemIndex,
            goodContracts[_landId][_itemIndex],
            msg.sender
        );
    }

    function detachLandGoods(
        uint256 _landId,
        uint256 _reason,
        address _remover
    ) external onlyAuthorized {
        if (goodContracts[_landId].length > 0) {
            uint256 counter = goodContracts[_landId].length;
            delete goodContracts[_landId];
            goodCounter = goodCounter - counter;
        }
        emit GoodsDetached(owner(), address(this), _remover, _landId, _reason);
    }

    function setMarketFee(uint256 _fee) external onlyOwner {
        marketFee = _fee;
    }

    function getMarketFee() external view returns (uint256 fee) {
        return marketFee;
    }

    function setOwner(address _newOwner) external onlyOwner {
        transferOwnership(_newOwner);
    }

    function getOwner() external view returns (address marketOwner) {
        return owner();
    }

    function getMarketContract()
        external
        view
        returns (address contractAddress)
    {
        return marketContract;
    }

    function setMarketContract(address market) external onlyOwner {
        marketContract = market;
    }

    function getGoodOwner(address _good) external view returns (address) {
        return ITropyverseGood(_good).getOwner();
    }

    function setGoodPrice(
        uint256 _landId,
        uint256 _index,
        uint256 _newPrice
    ) external onlyGoodOwner(_landId, _index) {
        ITropyverseGood(goodContracts[_landId][_index]).setPrice(_newPrice);
        emit GoodItemUpdated(
            goodContracts[_landId][_index],
            msg.sender,
            _newPrice,
            _landId,
            _index
        );
    }
}
