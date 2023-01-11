//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITropyverseAgent {
    struct Agent {
        address walletAddress;
        string recruiterCode;
        string agentCode;
        bool isActive;
    }

    function registerAsAgent() external;

    function deactivateAgent(address wallet) external;

    function getAgents() external view returns (Agent[] memory activeAgents);

    function getAgent(address wallet)
        external
        view
        returns (Agent memory agentDetails);

    function activateAgentCode(address wallet, string memory code) external;

    function activateRecruiterCode(address wallet, string memory code) external;

    function activateBothCodes(
        address wallet,
        string memory agentCode,
        string memory recruiterCode
    ) external;

    function hasAgentCode(address wallet) external view returns (bool);

    function hasRecruiterCode(address wallet) external view returns (bool);

    function isRegisteredAgent(address wallet) external view returns (bool);
}
