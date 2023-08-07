// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IExecutor} from "./IExecutor.sol";

interface IGovernance {
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