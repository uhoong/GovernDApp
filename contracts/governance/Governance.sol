// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IReview} from "../interfaces/IReview.sol";
import {IExecutor} from "../interfaces/IExecutor.sol";
import {IGovernance} from "../interfaces/IGovernance.sol";
import {IValidator} from "../interfaces/IValidator.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Governance is Ownable, IGovernance {
    // 主代码
    using SafeMath for uint256;

    mapping(uint256 => Proposal) private _proposals;
    mapping(address => bool) private _authorizedExecutors;
    uint256 private _proposalsCount;

    uint256 private _stakingDelay;
    address private _governanceStrategy;
    // uint256 private _reviewDuration;
    // uint256 private _executeDelay;

    uint256 private STAKE_THRESHOLD;

    IERC20 public immutable governanceToken;
    IReview public immutable review;

    constructor(
        address governanceStrategy,
        address _review,
        address _governanceToken,
        uint256 stakingDelay,
        uint256 stake_threshold,
        address[] memory executors
    ) {
        _setGovernanceStrategy(governanceStrategy);
        _setStakingDelay(stakingDelay);
        review = IReview(_review);
        governanceToken = IERC20(_governanceToken);
        _setStakeThreshold(stake_threshold);
        authorizeExecutors(executors);
    }

    function create(
        uint256 proposalType,
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

        require(
            IValidator(address(executor)).validateCreatorOfProposal(
                this,
                msg.sender,
                block.number - 1
            ),
            "PROPOSITION_CREATION_INVALID"
        );

        Proposal storage newProposal = _proposals[_proposalsCount];

        newProposal.id = _proposalsCount;
        newProposal.proposalType = proposalType;
        newProposal.creator = msg.sender;
        newProposal.executor = executor;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.withDelegatecalls = withDelegatecalls;

        newProposal.startBlock = block.number + _stakingDelay;
        newProposal.endBlock =
            newProposal.startBlock +
            review.REVIEW_DURATION();

        newProposal.strategy = _governanceStrategy;

        newProposal.ipfsHash = ipfsHash;

        _proposalsCount++;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            proposalType,
            executor,
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls,
            newProposal.startBlock,
            newProposal.endBlock,
            newProposal.strategy,
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
            IValidator(address(proposal.executor)).validateProposalCancellation(
                this,
                proposal.creator,
                block.number - 1
            ),
            "PROPOSITION_CANCELLATION_INVALID"
        );
        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            proposal.executor.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.executionBlock,
                proposal.withDelegatecalls[i]
            );
        }

        emit ProposalCanceled(proposalId);
    }

    function stakeForMarket(uint256 proposalId, uint256 amount) external {
        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Staking, "ONLY_STAKING");

        require(
            governanceToken.transferFrom(msg.sender, address(this), amount),
            "GOVERNACNETOKEN_TRANSFER_FAILED"
        );

        Proposal storage proposal = _proposals[proposalId];
        proposal.stakeAmount+=amount;
        proposal.stakes[msg.sender]+=amount;
    }

    function prepareMarket(uint256 proposalId) external{
        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Staking, "ONLY_STAKING");

        Proposal storage proposal = _proposals[proposalId];
        require(proposal.stakeAmount>STAKE_THRESHOLD,"STAKE_NOT_ENOUGH");

        proposal.marketReview = true;
    }
    
    function deposit(uint256 proposalId) external{
        ProposalState state = getProposalState(proposalId);
        require(state != ProposalState.Staking, "PROPOSAL_STAKING");

        Proposal storage proposal = _proposals[proposalId];
        uint256 amount = proposal.stakes[msg.sender];

        require(amount!=0,"ZERO_STAKE");
        proposal.stakes[msg.sender]=0;
        governanceToken.transfer(msg.sender,amount);
    }

    function getStakeOnProposal(uint256 proposalId, address user) external view override returns (uint256){
        Proposal storage proposal = _proposals[proposalId];
        return proposal.stakes[user];
    }

    // 提案投票/市场创建
    function createReview(uint256 proposalId) public {
        require(
            getProposalState(proposalId) == ProposalState.Active,
            "REVIEW_CLOSED"
        );
        // Proposal storage proposal = _proposals[proposalId];
        review.createReview(address(this), proposalId);
        // TODO:释放事件
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

    function isExecutorAuthorized(
        address executor
    ) public view override returns (bool) {
        return _authorizedExecutors[executor];
    }

    function queue(uint256 proposalId) external override {
        require(
            getProposalState(proposalId) == ProposalState.Succeeded,
            "INVALID_STATE_FOR_QUEUE"
        );
        Proposal storage proposal = _proposals[proposalId];
        uint256 executionBlock = block.number + proposal.executor.getDelay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(
                proposal.executor,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                executionBlock,
                proposal.withDelegatecalls[i]
            );
        }
        proposal.executionBlock = executionBlock;

        emit ProposalQueued(proposalId, executionBlock, msg.sender);
    }

    function _queueOrRevert(
        IExecutor executor,
        address target,
        uint256 value,
        string memory signature,
        bytes memory callData,
        uint256 executionBlock,
        bool withDelegatecall
    ) internal {
        require(
            !executor.isActionQueued(
                keccak256(
                    abi.encode(
                        target,
                        value,
                        signature,
                        callData,
                        executionBlock,
                        withDelegatecall
                    )
                )
            ),
            "DUPLICATED_ACTION"
        );
        executor.queueTransaction(
            target,
            value,
            signature,
            callData,
            executionBlock,
            withDelegatecall
        );
    }

    function execute(uint256 proposalId) external payable override {
        require(
            getProposalState(proposalId) == ProposalState.Queued,
            "ONLY_QUEUED_PROPOSALS"
        );
        Proposal storage proposal = _proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            proposal.executor.executeTransaction{value: proposal.values[i]}(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.executionBlock,
                proposal.withDelegatecalls[i]
            );
        }
        emit ProposalExecuted(proposalId, msg.sender);
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
            !IValidator(address(proposal.executor)).isProposalPassed(
                address(this),
                review,
                proposalId
            )
        ) {
            return ProposalState.Failed;
        } else if (proposal.executionBlock == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (
            proposal.executor.isProposalOverGracePeriod(this, proposalId)
        ) {
            return ProposalState.Expired;
        }else{
            return ProposalState.Queued;
        }
    }

    function getProposalById(
        uint256 proposalId
    ) external view override returns (ProposalInfo memory) {
        Proposal storage proposal = _proposals[proposalId];
        ProposalInfo memory proposalInfo = ProposalInfo({
            id: proposal.id,
            creator: proposal.creator,
            proposalType: proposal.proposalType,
            executor: proposal.executor,
            targets: proposal.targets,
            values: proposal.values,
            signatures: proposal.signatures,
            calldatas: proposal.calldatas,
            withDelegatecalls: proposal.withDelegatecalls,
            startBlock: proposal.startBlock,
            endBlock: proposal.endBlock,
            executionBlock: proposal.executionBlock,
            executed: proposal.executed,
            canceled: proposal.canceled,
            marketReview: proposal.marketReview,
            stakeAmount: proposal.stakeAmount,
            strategy: proposal.strategy,
            ipfsHash: proposal.ipfsHash
        });
        return proposalInfo;
    }

    function setGovernanceStrategy(
        address governanceStrategy
    ) external override onlyOwner {
        _setGovernanceStrategy(governanceStrategy);
    }

    function setStakingDelay(uint256 StakingDelay) external override onlyOwner {
        _setStakingDelay(StakingDelay);
    }

    function _authorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = true;
    }

    function _unauthorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = false;
    }

    function _setStakeThreshold(uint256 stake_threshold) internal{
        STAKE_THRESHOLD = stake_threshold;

        emit StakeThresholdChanged(stake_threshold, msg.sender);
    }

    function _setGovernanceStrategy(address governanceStrategy) internal {
        _governanceStrategy = governanceStrategy;

        emit GovernanceStrategyChanged(governanceStrategy, msg.sender);
    }

    function _setStakingDelay(uint256 stakingDelay) internal {
        _stakingDelay = stakingDelay;

        emit StakingDelayChanged(stakingDelay, msg.sender);
    }

    function getGovernanceStrategy() external view override returns (address) {
        return _governanceStrategy;
    }

    function getStakingDelay() external view override returns (uint256) {
        return _stakingDelay;
    }

    function getProposalsCount() external view override returns (uint256) {
        return _proposalsCount;
    }
}
