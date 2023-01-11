//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITicketFactory {
    function deleteTickets(
        uint256 _landId,
        uint256 reason,
        address remover
    ) external returns (uint256 landId);
}
