// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IExecutor} from "../interfaces/IExecutor.sol";
import {IGovernance} from "../interfaces/IGovernance.sol";
import {IValidator} from "../interfaces/IValidator.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Governance is Ownable, IGovernance {
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
        bytes32 ipfsHash
    );

    event ProposalCanceled(uint256 id);

    // 主代码
    using SafeMath for uint256;

    mapping(uint256 => Proposal) private _proposals;
    mapping(address => bool) private _authorizedExecutors;
    uint256 private _proposalsCount;

    uint256 private _stakeDelay;
    // uint256 private _reviewDuration;
    // uint256 private _executeDelay;

    // uint256 private GRACE_PERIOD;
    IERC20 public immutable governanceToken;
    IReview public immutable review;

    constructor(IERC20 _governanceToken,IReview _review) {
        _stakeDelay = 7200;
        // _reviewDuration = 19200;
        // _executeDelay = 7200;
        // GRACE_PERIOD = 7200;
        review = _review;
        governanceToken = _governanceToken;
    }

    // TODO：Governance 合约应提供创建市场的接口，这样才能以该市场的信息为准

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

        newProposal.startBlock = block.number + _stakeDelay;
        newProposal.endBlock = newProposal.startBlock + review.REVIEW_DURATION();
        // newProposal.executionBlock = newProposal.endBlock + _executeDelay;

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
                proposal.creator
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
                proposal.executionTime,
                proposal.withDelegatecalls[i]
            );
        }

        emit ProposalCanceled(proposalId);
    }

    // function stake(uint256 proposalId, uint256 amount) external {
    //     ProposalState state = getProposalState(proposalId);
    //     require(state == ProposalState.Staking, "ONLY_STAKING");

    //     require(
    //         governanceToken.transferFrom(msg.sender, address(this), amount),
    //         "GOVERNACNETOKEN_TRANSFER_FAILED"
    //     );

    //     Proposal storage proposal = _proposals[proposalId];
    //     proposal.stakeAmount+=amount;
    //     proposal.stakes[msg.sender]+=amount;
    // }

    // function deposit(uint256 proposalId) external{
    //     ProposalState state = getProposalState(proposalId);
    //     require(state != ProposalState.Staking, "PROPOSAL_STAKING");

    //     Proposal storage proposal = _proposals[proposalId];
    //     uint256 amount = proposal.stakes[msg.sender];

    //     require(amount!=0,"ZERO_STAKE");

    //     proposal.stakes[msg.sender]=0;
    //     governanceToken.transfer(msg.sender,amount);
    // }

    // function getStakeOnProposal(uint256 proposalId, address staker) external view returns (uint256){
    //     Proposal storage proposal = _proposals[proposalId];
    //     return proposal.stakes[staker];
    // }

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

    function execute(uint256 proposalId) external payable {
        require(
            getProposalState(proposalId) == ProposalState.Succeeded,
            "INVALID_STATE_FOR_EXECUTE"
        );
        Proposal storage proposal = _proposals[proposalId];
        require(
            block.timestamp >= proposal.executionBlock,
            "TIMELOCK_NOT_FINISHED"
        );
        require(
            block.timestamp <= proposal.executionBlock.add(GRACE_PERIOD),
            "GRACE_PERIOD_FINISHED"
        );

        bool success;
        bytes memory callData;
        bytes memory resultData;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            if (bytes(proposal.signatures[i]).length == 0) {
                callData = proposal.calldatas[i];
            } else {
                callData = abi.encodePacked(
                    bytes4(keccak256(bytes(proposal.signatures[i]))),
                    proposal.calldatas[i]
                );
            }

            if (proposal.withDelegatecalls[i]) {
                require(
                    msg.value >= proposal.values[i],
                    "NOT_ENOUGH_MSG_VALUE"
                );
                (success, resultData) = proposal.targets[i].delegatecall(
                    callData
                );
            } else {
                (success, resultData) = proposal.targets[i].call{
                    value: proposal.values[i]
                }(callData);
            }
        }
    }

    // 提案执行相关函数，governance 合约负责 executor 合约执行交易，具体的执行过程由 executor 合约执行
    function _authorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = true;
    }

    function _unauthorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = false;
    }

    // 提案投票/市场创建
    function createReview(uint256 proposalId) public {
        require(
            getProposalState(proposalId) == ProposalState.Active,
            "REVIEW_CLOSED"
        );
        Proposal storage proposal = _proposals[proposalId];
        return review.createReview(proposalId,proposal.endBlock);
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
                this,
                proposalId
            )
        ) {
            return ProposalState.Failed;
        } else if (proposal.executionBlock == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (
            IValidator(address(proposal.executor)).isProposalOverGracePeriod(
                this,
                proposalId
            )
        ) {
            return ProposalState.Expired;
        }
    }

    function getProposalById(
        uint256 proposalId
    ) external view override returns (ProposalInfo memory) {
        Proposal storage proposal = _proposals[proposalId];
        ProposalInfo memory proposalInfo = ProposalInfo({
            id: proposal.id,
            creator: proposal.creator,
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
            ipfsHash: proposal.ipfsHash
        });
        return proposalInfo;
    }
}