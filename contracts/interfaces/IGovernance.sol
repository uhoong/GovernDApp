// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IExecutor} from "./IExecutor.sol";

interface IGovernance {
    enum ProposalState {
        Pending,
        Canceled,
        Active,
        Failed,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct Proposal {
        uint256 id;
        address creator;
        IExecutor executor;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        uint256 startBlock;
        uint256 endBlock;
        uint256 executionTime;
        // uint256 forVotes;
        // uint256 againstVotes;
        bool executed;
        bool canceled;
        address strategy;
        bytes32 ipfsHash;
        // mapping(address => Vote) votes;
    }

    function create(
        IExecutorWithTimelock executor,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls,
        bytes32 ipfsHash
    ) external returns (uint256);

    function cancel(uint256 proposalId) external;

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external payable;

    // 通过治理合约接口对提案进行评议
    // TODO：接入 strategy 合约，如何选择评议方式
    function eval(uint256 proposalId);

    function setGovernanceStrategy(address governanceStrategy) external;

    function getProposalState(uint256 proposalId) external view returns (ProposalState);
}
