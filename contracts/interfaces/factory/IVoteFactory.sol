// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IVoteFactory {
    function createVote(
        address governance,
        uint256 proposalId
    ) external returns (address);

    function getContractAddress(
        address governance,
        uint256 proposalId
    ) external view returns (address);
}
