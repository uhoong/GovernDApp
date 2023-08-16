// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IValidator} from "../interfaces/IValidator.sol";
import {IReview} from "../interfaces/IReview.sol";
import {IGovernance} from "../interfaces/IGovernance.sol";
import {GovernToken} from "../token/GovernToken.sol";

contract Validator is IValidator {
    GovernToken public immutable GT;

    uint256 public immutable override PROPOSITION_THRESHOLD;
    uint256 public immutable override VOTING_DURATION;
    uint256 public immutable override VOTE_DIFFERENTIAL;
    uint256 public immutable override MINIMUM_QUORUM;
    uint256 public constant override ONE_HUNDRED_WITH_PRECISION = 10000;

    constructor(
        address token,
        uint256 propositionThreshold,
        uint256 votingDuration,
        uint256 voteDifferential,
        uint256 minimumQuorum
    ) {
        GT = GovernToken(token);
        PROPOSITION_THRESHOLD = propositionThreshold;
        VOTING_DURATION = votingDuration;
        VOTE_DIFFERENTIAL = voteDifferential;
        MINIMUM_QUORUM = minimumQuorum;
    }

    function validateCreatorOfProposal(
        IGovernance governance,
        address user,
        uint256 blockNumber
    ) external view returns (bool) {
        return isPowerEnough(governance, user, blockNumber);
    }

    function validateProposalCancellation(
        IGovernance governance,
        address user,
        uint256 blockNumber
    ) external view returns (bool) {
        return !isPowerEnough(governance, user, blockNumber);
    }

    function validateCreateOfMarket(
        IGovernance governance,
        address user
    ) external view returns (bool) {}

    function isProposalPassed(
        address governance,
        IReview review,
        uint256 proposalId
    ) external view returns (bool) {
        return review.isProposalPassed(governance, proposalId);
    }

    // function isProposalPassed(
    //     IGovernance governance,
    //     uint256 proposalId
    // ) external view returns (bool) {

    // }

    function getMinimumPowerNeeded(
        IGovernance governance,
        uint256 blockNumber
    ) public view override returns (uint256) {
        return
            (GT.totalSupply() * PROPOSITION_THRESHOLD) /
            ONE_HUNDRED_WITH_PRECISION;
    }

    function isPowerEnough(
        IGovernance governance,
        address user,
        uint256 blockNumber
    ) public view override returns (bool) {
        return
            GT.getVotingPowerAt(user, blockNumber) >=
            getMinimumPowerNeeded(governance, blockNumber);
    }
}
