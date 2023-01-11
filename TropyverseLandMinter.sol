//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interface/ITropyverseLand.sol";
import "./interface/IAgentPaymentHistory.sol";
import "./interface/ITropyverseAgent.sol";

import "hardhat/console.sol";

contract TropyverseLandMinter is Ownable {
    // error status strings
    string private constant MAX_PER_WALLET_REACHED = "Exceeded per wallet!";
    string private constant MAX_MINT_AMOUNT_PER_TX = "Exceeded max per tx";
    string private constant SUPPLY_LIMIT_ERROR = "Max Supply reached";
    string private constant INVALID_SIGNATURE = "Invalid signature";
    // limit variables
    uint256 public constant MAX_SUPPLY = 10200;
    uint256 constant MAX_PER_WALLET = 10;
    uint256 constant PURCHASE_LIMIT = 5;
    // mint functions activators
    bool public publicMint = true;
    bool public mintWithCommission = true;
    bool public mintWithAgent = true;

    address private paymentHistoryContract;
    address private agentContract;
    address private tropyverseLand;

    event NewToken(address indexed _receiver, uint256 _tokenId, string ipfsUri);
    event NewTokens(address indexed _receiver, uint256 _totalPrice, Token[]);
    event NewTokensWithCommission(
        address indexed receiver,
        uint256 _totalPrice,
        Token[],
        address _recruiter,
        address _agent
    );

    struct Token {
        string tokenURI;
        uint256 tokenId;
    }
    event Deposit(address indexed _receiver, uint256 _amount);
    event Withdraw(address indexed _receiver, uint256 _amount);

    modifier hasAgentCode(address wallet) {
        require(
            ITropyverseAgent(agentContract).hasAgentCode(wallet),
            "Agent Not exists"
        );
        _;
    }
    modifier hasRecruiterCode(address wallet) {
        require(
            ITropyverseAgent(agentContract).hasRecruiterCode(wallet),
            "Agent Not exists"
        );
        _;
    }
    modifier mintCompliance(string[] memory _assets) {
        uint256 ownerMintedCount = ITropyverseLand(tropyverseLand)
            .getMintedBalance(msg.sender);
        require(publicMint == true, "public sale is not active");
        require(
            (_assets.length + ownerMintedCount) <= MAX_PER_WALLET,
            MAX_PER_WALLET_REACHED
        );
        require(
            _assets.length > 0 && _assets.length <= PURCHASE_LIMIT,
            MAX_MINT_AMOUNT_PER_TX
        );

        require(
            ITropyverseLand(tropyverseLand).getTotalSupply() + _assets.length <=
                MAX_SUPPLY,
            SUPPLY_LIMIT_ERROR
        );
        _;
    }

    constructor(
        address _agentContract,
        address _paymentContract,
        address _landContract
    ) {
        agentContract = _agentContract;
        paymentHistoryContract = _paymentContract;
        tropyverseLand = _landContract;
    }

    // set and get functions

    function getAgentContract() external view onlyOwner returns (address) {
        return agentContract;
    }

    function setAgentContract(address _contract) external onlyOwner {
        agentContract = _contract;
    }

    function getLandContract()
        external
        view
        onlyOwner
        returns (address landContract)
    {
        return address(tropyverseLand);
    }

    function setLandContract(address land) external onlyOwner {
        tropyverseLand = land;
    }

    function setMintWithCommissionActive(bool _status) external onlyOwner {
        mintWithCommission = _status;
    }

    function setMintWithAgentActive(bool _status) external onlyOwner {
        mintWithAgent = _status;
    }

    function getAgentPaymentContract()
        external
        view
        onlyOwner
        returns (address)
    {
        return paymentHistoryContract;
    }

    function setAgentPaymentContract(address _contract)
        external
        onlyOwner
        returns (address)
    {
        paymentHistoryContract = _contract;
        return _contract;
    }

    // create land functions

    function createLand(
        string[] memory _assets,
        string memory _nonce,
        bytes calldata _signature
    ) external payable mintCompliance(_assets) {
        require(
            verifySignature(msg.sender, _assets, msg.value, _nonce, _signature),
            INVALID_SIGNATURE
        );

        address manager = ITropyverseLand(tropyverseLand).getManager();
        uint256 _managerPart = msg.value / 100;
        uint256 _marketPart = msg.value - _managerPart;

        (bool _managerPartSent, ) = payable(manager).call{value: _managerPart}(
            ""
        );
        require(_managerPartSent, "Failed to send Ether");
        emit Deposit(manager, _managerPart);

        (bool _marketPartSent, ) = payable(owner()).call{value: _marketPart}(
            ""
        );
        require(_marketPartSent, "Failed to send Ether");
        emit Deposit(owner(), _marketPart);

        createLandLoop(_msgSender(), msg.value, _assets);

        IAgentPaymentHistory(paymentHistoryContract).updateTransferHistory(
            manager,
            _managerPart
        );
        IAgentPaymentHistory(paymentHistoryContract).updateTransferHistory(
            owner(),
            _marketPart
        );

        ITropyverseLand(tropyverseLand).setNonceUsed(_nonce);
    }

    function createLandWithCommission(
        string[] memory _assets,
        address _recruiter,
        address _agent,
        string memory _nonce,
        bytes calldata _signature
    ) external payable mintCompliance(_assets) {
        require(
            mintWithCommission == true,
            "sale with commission is not active"
        );
        require(
            verifySignature(msg.sender, _assets, msg.value, _nonce, _signature),
            INVALID_SIGNATURE
        );

        createLandLoop(_msgSender(), msg.value, _assets, _recruiter, _agent);

        transferFunds(_recruiter, _agent, msg.value);
        updateReferralHistory(_recruiter, _agent, msg.value);

        ITropyverseLand(tropyverseLand).setNonceUsed(_nonce);
    }

    function createLandWithAgent(
        string[] memory _assets,
        address _recruiter,
        address _agent,
        string memory _nonce,
        bytes calldata _signature
    )
        external
        payable
        hasRecruiterCode(_recruiter)
        hasAgentCode(_agent)
        mintCompliance(_assets)
    {
        require(mintWithAgent == true, "sale with agent is not active");
        require(
            verifySignature(msg.sender, _assets, msg.value, _nonce, _signature),
            INVALID_SIGNATURE
        );

        createLandLoop(_msgSender(), msg.value, _assets, _recruiter, _agent);

        transferFunds(_recruiter, _agent, msg.value);
        updateReferralHistory(_recruiter, _agent, msg.value);
        ITropyverseLand(tropyverseLand).setNonceUsed(_nonce);
    }

    function createLandLoop(
        address _receiver,
        uint256 _total,
        string[] memory _assets
    ) internal {
        Token[] memory _tokens = new Token[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            if (ITropyverseLand(tropyverseLand).getUsedUri(_assets[i])) {
                revert("Token Already minted");
            } else {
                ITropyverseLand(tropyverseLand).adminMint(
                    _receiver,
                    _assets[i]
                );
                uint256 newTokenId = ITropyverseLand(tropyverseLand)
                    .totalSupply();
                _tokens[i] = Token({tokenId: newTokenId, tokenURI: _assets[i]});
            }
        }

        emit NewTokens(_msgSender(), _total, _tokens);
    }

    // internal functions
    function createLandLoop(
        address _receiver,
        uint256 _total,
        string[] memory _assets,
        address _recruiter,
        address _manager
    ) internal {
        Token[] memory _tokens = new Token[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            if (ITropyverseLand(tropyverseLand).getUsedUri(_assets[i])) {
                revert("Token Already minted");
            } else {
                ITropyverseLand(tropyverseLand).adminMint(
                    _receiver,
                    _assets[i]
                );
                uint256 newTokenId = ITropyverseLand(tropyverseLand)
                    .totalSupply();
                _tokens[i] = Token({tokenId: newTokenId, tokenURI: _assets[i]});
            }
        }

        emit NewTokensWithCommission(
            _msgSender(),
            _total,
            _tokens,
            _recruiter,
            _manager
        );
    }

    function updateReferralHistory(
        address rec,
        address agent,
        uint256 amount
    ) internal {
        uint256 _recruiterPart = amount / 100;
        uint256 _agentPart = (amount / 100) * 8;
        uint256 _managerPart = amount / 100;
        uint256 _marketPart = amount -
            (_recruiterPart + _agentPart + _managerPart);

        address manager = ITropyverseLand(tropyverseLand).getManager();

        IAgentPaymentHistory(paymentHistoryContract).updateTransferHistory(
            rec,
            _recruiterPart
        );

        IAgentPaymentHistory(paymentHistoryContract).updateTransferHistory(
            agent,
            _agentPart
        );

        IAgentPaymentHistory(paymentHistoryContract).updateTransferHistory(
            manager,
            _managerPart
        );
        IAgentPaymentHistory(paymentHistoryContract).updateTransferHistory(
            owner(),
            _marketPart
        );
    }

    function verifySignature(
        address _receiver,
        string[] memory _assets,
        uint256 price,
        string memory _nonce,
        bytes calldata _signature
    ) internal view returns (bool) {
        require(
            !ITropyverseLand(tropyverseLand).getNonce(_nonce),
            INVALID_SIGNATURE
        );
        string memory tokens;
        for (uint256 i = 0; i < _assets.length; i++) {
            tokens = string(abi.encodePacked(tokens, _assets[i]));
        }

        bytes32 hashValue = keccak256(
            abi.encodePacked(_receiver, tokens, price, _nonce)
        );
        bytes32 message = ECDSA.toEthSignedMessageHash(hashValue);
        address signer = ECDSA.recover(message, _signature);
        require(
            _receiver != address(0) &&
                signer == ITropyverseLand(tropyverseLand).getSignerAddress(),
            INVALID_SIGNATURE
        );
        return signer == ITropyverseLand(tropyverseLand).getSignerAddress();
    }

    function transferFunds(
        address _rec,
        address agent,
        uint256 amount
    ) internal {
        address manager = ITropyverseLand(tropyverseLand).getManager();

        uint256 _recruiterPart = amount / 100;
        uint256 _agentPart = (amount / 100) * 8;
        uint256 _managerPart = amount / 100;
        uint256 _marketPart = amount -
            (_recruiterPart + _agentPart + _managerPart);

        (bool _recruiterPartSent, ) = payable(_rec).call{value: _recruiterPart}(
            ""
        );

        require(_recruiterPartSent, "Failed to send Ether");
        emit Deposit(_rec, _recruiterPart);

        (bool _agentPartSent, ) = payable(agent).call{value: _agentPart}("");
        require(_agentPartSent, "Failed to send Ether");
        emit Deposit(agent, _agentPart);

        (bool _managerPartSent, ) = payable(manager).call{value: _managerPart}(
            ""
        );
        require(_managerPartSent, "Failed to send Ether");
        emit Deposit(manager, _managerPart);

        (bool _marketPartSend, ) = payable(owner()).call{value: _marketPart}(
            ""
        );
        require(_marketPartSend, "Failed to send Ether");
    }

    function verifyTransactionHistory(bytes calldata _signature)
        internal
        view
        returns (bool)
    {
        bytes32 hashValue = keccak256(abi.encodePacked(msg.sender));
        bytes32 message = ECDSA.toEthSignedMessageHash(hashValue);
        address signer = ECDSA.recover(message, _signature);
        return signer == ITropyverseLand(tropyverseLand).getSignerAddress();
    }
}
