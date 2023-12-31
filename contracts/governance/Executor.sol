// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernance} from "../interfaces/IGovernance.sol";
import {IExecutor} from "../interfaces/IExecutor.sol";
import {Validator} from "./Validator.sol";

contract Executor is IExecutor, Validator{
    uint256 public immutable override GRACE_PERIOD;
    uint256 public immutable override MINIMUM_DELAY;
    uint256 public immutable override MAXIMUM_DELAY;

    address private _admin;
    address private _pendingAdmin;
    uint256 private _delay;

    mapping(bytes32 => bool) private _queuedTransactions;

    constructor(
        address admin,
        uint256 delay,
        uint256 gracePeriod,
        uint256 minimumDelay,
        uint256 maximumDelay,
        address token,
        uint256 propositionThreshold
        // uint256 votingDuration,
        // uint256 voteDifferential,
        // uint256 minimumQuorum
    ) Validator(token,propositionThreshold){
        require(delay >= minimumDelay, "DELAY_SHORTER_THAN_MINIMUM");
        require(delay <= maximumDelay, "DELAY_LONGER_THAN_MAXIMUM");
        _delay = delay;
        _admin = admin;

        GRACE_PERIOD = gracePeriod;
        MINIMUM_DELAY = minimumDelay;
        MAXIMUM_DELAY = maximumDelay;

        // emit NewDelay(delay);
        // emit NewAdmin(admin);
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin, "ONLY_BY_ADMIN");
        _;
    }

    modifier onlyExecutor() {
        require(msg.sender == address(this), "ONLY_BY_THIS_TIMELOCK");
        _;
    }

    modifier onlyPendingAdmin() {
        require(msg.sender == _pendingAdmin, "ONLY_BY_PENDING_ADMIN");
        _;
    }

    /**
     * @dev Set the delay
     * @param delay delay between queue and execution of proposal
     **/
    function setDelay(uint256 delay) public onlyExecutor {
        _validateDelay(delay);
        _delay = delay;

        emit NewDelay(delay);
    }

    /**
     * @dev Function enabling pending admin to become admin
     **/
    function acceptAdmin() public onlyPendingAdmin {
        _admin = msg.sender;
        _pendingAdmin = address(0);

        emit NewAdmin(msg.sender);
    }

    /**
     * @dev Setting a new pending admin (that can then become admin)
     * Can only be called by this executor (i.e via proposal)
     * @param newPendingAdmin address of the new admin
     **/
    function setPendingAdmin(address newPendingAdmin) public onlyExecutor {
        _pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin(newPendingAdmin);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executionBlock,
        bool withDelegatecall
    ) public override onlyAdmin returns (bytes32) {
        require(
            executionBlock >= block.number + _delay,
            "EXECUTION_TIME_UNDERESTIMATED"
        );

        bytes32 actionHash = keccak256(
            abi.encode(
                target,
                value,
                signature,
                data,
                executionBlock,
                withDelegatecall
            )
        );
        _queuedTransactions[actionHash] = true;

        emit QueuedAction(
            actionHash,
            target,
            value,
            signature,
            data,
            executionBlock,
            withDelegatecall
        );
        return actionHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executionBlock,
        bool withDelegatecall
    ) public override onlyAdmin returns (bytes32) {
        bytes32 actionHash = keccak256(
            abi.encode(
                target,
                value,
                signature,
                data,
                executionBlock,
                withDelegatecall
            )
        );
        _queuedTransactions[actionHash] = false;

        emit CancelledAction(
            actionHash,
            target,
            value,
            signature,
            data,
            executionBlock,
            withDelegatecall
        );
        return actionHash;
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executionBlock,
        bool withDelegatecall
    ) public payable override onlyAdmin returns (bytes memory) {
        bytes32 actionHash = keccak256(
            abi.encode(
                target,
                value,
                signature,
                data,
                executionBlock,
                withDelegatecall
            )
        );
        require(_queuedTransactions[actionHash], "ACTION_NOT_QUEUED");
        require(block.number >= executionBlock, "TIMELOCK_NOT_FINISHED");
        require(
            block.number <= executionBlock + GRACE_PERIOD,
            "GRACE_PERIOD_FINISHED"
        );

        _queuedTransactions[actionHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        bool success;
        bytes memory resultData;
        if (withDelegatecall) {
            require(msg.value >= value, "NOT_ENOUGH_MSG_VALUE");
            // solium-disable-next-line security/no-call-value
            (success, resultData) = target.delegatecall(callData);
        } else {
            // solium-disable-next-line security/no-call-value
            (success, resultData) = target.call{value: value}(callData);
        }

        require(success, "FAILED_ACTION_EXECUTION");

        emit ExecutedAction(
            actionHash,
            target,
            value,
            signature,
            data,
            executionBlock,
            withDelegatecall,
            resultData
        );

        return resultData;
    }

    /**
     * @dev Getter of the current admin address (should be governance)
     * @return The address of the current admin
     **/
    function getAdmin() external view override returns (address) {
        return _admin;
    }

    /**
     * @dev Getter of the current pending admin address
     * @return The address of the pending admin
     **/
    function getPendingAdmin() external view override returns (address) {
        return _pendingAdmin;
    }

    /**
     * @dev Getter of the delay between queuing and execution
     * @return The delay in seconds
     **/
    function getDelay() external view override returns (uint256) {
        return _delay;
    }

    /**
     * @dev Returns whether an action (via actionHash) is queued
     * @param actionHash hash of the action to be checked
     * keccak256(abi.encode(target, value, signature, data, executionBlock, withDelegatecall))
     * @return true if underlying action of actionHash is queued
     **/
    function isActionQueued(
        bytes32 actionHash
    ) external view override returns (bool) {
        return _queuedTransactions[actionHash];
    }

    /**
     * @dev Checks whether a proposal is over its grace period
     * @param governance Governance contract
     * @param proposalId Id of the proposal against which to test
     * @return true of proposal is over grace period
     **/
    function isProposalOverGracePeriod(
        IGovernance governance,
        uint256 proposalId
    ) external view override returns (bool) {
        IGovernance.ProposalInfo memory proposal = governance.getProposalById(
            proposalId
        );

        return (block.number > proposal.executionBlock + GRACE_PERIOD);
    }

    function _validateDelay(uint256 delay) internal view {
        require(delay >= MINIMUM_DELAY, "DELAY_SHORTER_THAN_MINIMUM");
        require(delay <= MAXIMUM_DELAY, "DELAY_LONGER_THAN_MAXIMUM");
    }

    receive() external payable {}
}
