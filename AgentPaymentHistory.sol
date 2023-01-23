//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";

contract AgentPaymentHistory is Ownable {
    address private operator;

    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || msg.sender == operator,
            "NOT_AUTHORIZED"
        );
        _;
    }

    mapping(address => uint256) private transferHistory;

    function updateTransferHistory(
        address _agent,
        uint256 _amount
    ) external onlyAuthorized returns (address agent, uint256 amount) {
        transferHistory[_agent] += _amount;
        return (_agent, transferHistory[_agent]);
    }

    // this function is used to get history of payed commission to specific account
    function getTransferHistory(
        address _wallet
    ) external view returns (uint256) {
        require(_wallet != address(0), "Trying to query none existent agent");
        return transferHistory[_wallet];
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
