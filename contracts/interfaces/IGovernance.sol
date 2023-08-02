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
        uint256 executionBlock;
        
        bool executed;
        bool canceled;

        // bool voteReview;
        //如果为 true，提案由预测市场决定，否则由投票决定。TODO：是否加入预测市场辅助的评议方式 
        bool marketReview;
        uint256 stakeAmount;

        bytes32 ipfsHash;
        mapping(address => uint256) stakes;
    }

    struct ProposalInfo {
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
        uint256 executionBlock;
        
        bool executed;
        bool canceled;

        bool marketReview;
        uint256 stakeAmount;  

        bytes32 ipfsHash;
    }

    event ProposalCreated(
        uint256 id,
        address indexed creator,
        IExecutor indexed executor,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        bool[] withDelegatecalls,
        uint256 startBlock,
        uint256 endBlock,
        bytes32 ipfsHash
    );

    event ProposalCanceled(uint256 id);

    function create(
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
    function stake(
        uint256 proposalId,
        uint256 amount
    ) external;

    function deposit(uint256 proposalId) external;

    function getStakeOnProposal(uint256 proposalId, address staker) external view returns (uint256);

    // 提案执行相关函数，governance 合约负责 executor 合约执行交易，具体的执行过程由 executor 合约执行
    function authorizeExecutors(address[] memory executors) external;

    function unauthorizeExecutors(address[] memory executors) external;

    function isExecutorAuthorized(address executor) external view returns (bool);

    function execute(uint256 proposalId) external payable;

    // 合约状态
    function getProposalState(uint256 proposalId) external view returns (ProposalState);

    function getProposalById(uint256 proposalId) external view returns (ProposalInfo memory);
}