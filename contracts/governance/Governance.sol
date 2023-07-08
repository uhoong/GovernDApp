// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IExecutor} from "../interfaces/IExecutor";
import {IGovernance} from "../interfaces/IGovernance.sol";

contract Governance is Ownable, IGovernance {
    mapping(uint256 => Proposal) private _proposals;
    mapping(address => bool) private _authorizedExecutors;
    uint256 private _proposalsCount;

    uint256 private _stakeDelay;
    uint256 private _reviewDuration;
    uint256 private _executeDelay;

    function create(
        IExecutor executor,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls,
        bytes32 ipfsHash
    ) external returns (uint256) {
        require(targets.length != 0, "INVALID_EMPTY_TARGETS");
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length &&
                targets.length == withDelegatecalls.length,
            "INCONSISTENT_PARAMS_LENGTH"
        );

        require(
            isExecutorAuthorized(address(executor)),
            "EXECUTOR_NOT_AUTHORIZED"
        );

        // 保持创建者的币值一直高于阈值
        require(
            IProposalValidator(address(executor)).validateCreatorOfProposal(
                this,
                msg.sender
            ),
            "PROPOSITION_CREATION_INVALID"
        );

        Proposal storage newProposal = proposals[_proposalCount];

        newProposal.id = _proposalCount;
        newProposal.creator = msg.sender;
        newProposal.executor = executor;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.withDelegatecalls = withDelegatecalls;

        newProposal.startBlock = block.number + _stakeDelay;
        newProposal.endBlock = newProposal.startBlock + _reviewDuration;
        newProposal.executionBlock = newProposal.endBlock + _executeDelay;

        newProposal.ipfsHash = ipfsHash;

        _proposalCount++;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            executor,
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls,
            newProposal.startBlock,
            newProposal.endBlock,
            ipfsHash
        );

        return newProposal.id;
    }

    function cancel(uint256 proposalId) external override {
        ProposalState state = getProposalState(proposalId);
        require(
            state != ProposalState.Executed &&
                state != ProposalState.Canceled &&
                state != ProposalState.Expired,
            "ONLY_BEFORE_EXECUTED"
        );

        Proposal storage proposal = _proposals[proposalId];
        require(
            IProposalValidator(address(proposal.executor))
                .validateProposalCancellation(this, proposal.creator),
            "PROPOSITION_CANCELLATION_INVALID"
        );
        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }

    // 提案执行相关函数，governance 合约负责 executor 合约执行交易，具体的执行过程由 executor 合约执行
    function authorizeExecutors(
        address[] memory executors
    ) public override onlyOwner {
        for (uint256 i = 0; i < executors.length; i++) {
            _authorizeExecutor(executors[i]);
        }
    }

    function unauthorizeExecutors(
        address[] memory executors
    ) public override onlyOwner {
        for (uint256 i = 0; i < executors.length; i++) {
            _unauthorizeExecutor(executors[i]);
        }
    }

    // 提案执行相关函数，governance 合约负责 executor 合约执行交易，具体的执行过程由 executor 合约执行
    function _authorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = true;
    }

    function _unauthorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = false;
    }

    // 提案信息获取
    function getProposalState(
        uint256 proposalId
    ) public view override returns (ProposalState) {
        require(_proposalsCount >= proposalId, "INVALID_PROPOSAL_ID");
        Proposal storage proposal = _proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Staking;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            !IProposalValidator(address(proposal.executor)).isProposalPassed(
                this,
                proposalId
            )
        ) {
            return ProposalState.Failed;
        } else if (proposal.executionTime == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (
            proposal.executor.isProposalOverGracePeriod(this, proposalId)
        ) {
            return ProposalState.Expired;
            
        }
    }
}
