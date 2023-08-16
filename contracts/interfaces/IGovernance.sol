// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IExecutor} from "./IExecutor.sol";

interface IGovernance {
    enum ProposalState {
        Staking,
        Canceled,
        Active,
        Failed,
        Succeeded,
        Expired,
        Executed,
        Queued
    }

    struct Proposal {
        uint256 id;
        address creator;
        uint256 proposalType; //暂时没用的字段
        IExecutor executor;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        uint256 startBlock; //提案在创建后，会有几天的等待时间
        uint256 endBlock; //在endblock前可以投票
        uint256 executionBlock; //在executionBlock后才可以执行
        bool executed;
        bool canceled;
        // bool voteReview;
        //如果为 true，提案由预测市场决定，否则由投票决定。TODO：是否加入预测市场辅助的评议方式
        bool marketReview; //暂时没用的字段
        uint256 stakeAmount; //暂时没用的字段
        address strategy;
        bytes32 ipfsHash;
        mapping(address => uint256) stakes; //暂时没用的字段
    }

    struct ProposalInfo {
        uint256 id;
        address creator;
        uint256 proposalType; //暂时没用的字段
        IExecutor executor;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        uint256 startBlock;
        uint256 endBlock;
        uint256 executionBlock;
        bool executed;
        bool canceled;
        bool marketReview;
        uint256 stakeAmount;
        address strategy;
        bytes32 ipfsHash;
    }

    event ProposalCreated(
        uint256 id,
        address indexed creator,
        uint256 proposalType,
        IExecutor indexed executor,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        bool[] withDelegatecalls,
        uint256 startBlock,
        uint256 endBlock,
        address strategy,
        bytes32 ipfsHash
    );

    event ProposalCanceled(uint256 id);

    event ProposalQueued(
        uint256 id,
        uint256 executionBlock,
        address indexed initiatorQueueing
    );

    event ProposalExecuted(uint256 id, address indexed initiatorExecution);

    event GovernanceStrategyChanged(
        address indexed newStrategy,
        address indexed initiatorChange
    );

    event StakingDelayChanged(
        uint256 newStakingDelay,
        address indexed initiatorChange
    );

    function create(
        uint256 proposalType,
        IExecutor executor,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls,
        bytes32 ipfsHash
    ) external returns (uint256);

    function cancel(uint256 proposalId) external;

    // 合约评议方式
    // function stake(
    //     uint256 proposalId,
    //     uint256 amount
    // ) external;

    // function deposit(uint256 proposalId) external;

    // function getStakeOnProposal(uint256 proposalId, address staker) external view returns (uint256);

    // 提案执行相关函数，governance 合约负责 executor 合约执行交易，具体的执行过程由 executor 合约执行
    function authorizeExecutors(address[] memory executors) external;

    function unauthorizeExecutors(address[] memory executors) external;

    function isExecutorAuthorized(
        address executor
    ) external view returns (bool);

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external payable;

    function createReview(uint256 proposalId) external;

    function setGovernanceStrategy(address governanceStrategy) external;

    function setStakingDelay(uint256 votingDelay) external;

    function getGovernanceStrategy() external view returns (address);

    function getStakingDelay() external view returns (uint256);

    function getProposalsCount() external view returns (uint256);

    // 合约状态
    function getProposalState(
        uint256 proposalId
    ) external view returns (ProposalState);

    function getProposalById(
        uint256 proposalId
    ) external view returns (ProposalInfo memory);
}
