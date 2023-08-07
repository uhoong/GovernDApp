// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IVoteFactory{
    function createVote(uint256 proposalId,uint256 startBlock,uint256 endBlock) external returns(address);
}