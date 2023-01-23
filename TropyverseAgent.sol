// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";

contract TropyverseAgent is Ownable {
    struct Agent {
        address walletAddress;
        string recruiterCode;
        string agentCode;
        bool isActive;
    }

    mapping(address => Agent) private agents;
    address[] agentWallets;
    address operator;

    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || msg.sender == operator,
            "Caller is not authorized to run this transaction"
        );
        _;
    }

    modifier agentExists(address wallet) {
        require(agents[wallet].walletAddress != address(0), "Agent Not Exists");
        _;
    }

    modifier agentNotExists(address wallet) {
        require(
            agents[wallet].walletAddress == address(0),
            "Agent Already registered"
        );
        _;
    }

    function registerAsAgent() external agentNotExists(msg.sender) {
        require(
            agents[msg.sender].walletAddress == address(0),
            "Agent already exists"
        );
        agents[msg.sender].walletAddress = msg.sender;
        agentWallets.push(msg.sender);
    }

    function deactivateAgent(address wallet) external onlyOwner {
        require(agents[wallet].isActive == true, "Agent is already disabled ");
        agents[wallet].isActive = false;
    }

    function getAgents()
        external
        view
        onlyAuthorized
        returns (Agent[] memory activeAgents)
    {
        Agent[] memory agentsList = new Agent[](agentWallets.length);
        for (uint256 i = 0; i < agentWallets.length; i++) {
            agentsList[i] = agents[agentWallets[i]];
        }

        return agentsList;
    }

    function getAgent(
        address wallet
    ) external view onlyAuthorized returns (Agent memory agentDetails) {
        return agents[wallet];
    }

    function activateAgentCode(
        address wallet,
        string memory code
    ) external onlyOwner agentExists(wallet) {
        agents[wallet].isActive = true;
        agents[wallet].agentCode = code;
    }

    function activateRecruiterCode(
        address wallet,
        string memory code
    ) external onlyOwner agentExists(wallet) {
        agents[wallet].isActive = true;
        agents[wallet].recruiterCode = code;
    }

    function activateBothCodes(
        address wallet,
        string memory agentCode,
        string memory recruiterCode
    ) external onlyOwner agentExists(wallet) {
        agents[wallet].isActive = true;
        agents[wallet].agentCode = agentCode;
        agents[wallet].recruiterCode = recruiterCode;
    }

    function hasRecruiterCode(
        address wallet
    ) external view returns (bool isActive) {
        if (agents[wallet].isActive == false) {
            return false;
        }
        if (agents[wallet].walletAddress == address(0)) {
            return false;
        }

        if (isEmpty(agents[wallet].recruiterCode)) {
            return false;
        }

        return true;
    }

    function hasAgentCode(
        address wallet
    ) external view returns (bool isActive) {
        if (agents[wallet].isActive == false) {
            return false;
        }
        if (agents[wallet].walletAddress == address(0)) {
            return false;
        }

        if (isEmpty(agents[wallet].agentCode)) {
            return false;
        }

        return true;
    }

    function isRegisteredAgent(
        address wallet
    ) external view returns (bool isRegistered) {
        return (agents[wallet].walletAddress == address(0) ? false : true);
    }

    function getOperator() external view returns (address) {
        return operator;
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function isEmpty(string memory _str) internal pure returns (bool _isEmpty) {
        bytes memory input = bytes(_str);
        if (input.length == 0) {
            return true;
        } else {
            return false;
        }
    }
}
