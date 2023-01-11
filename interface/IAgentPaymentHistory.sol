//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IAgentPaymentHistory {
    function updateTransferHistory(address _agent, uint256 _amount)
        external
        returns (address, uint256);

    // this function is used to get history of payed commission to specific account
    function getTransferHistory(address _wallet)
        external
        view
        returns (uint256);

    function setOperator(address newOperator) external;

    function getOperator() external returns (address);
}
