// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernance} from "./IGovernance.sol";

interface IValidator {
    function PROPOSITION_THRESHOLD() external view returns (uint256);

    function VOTING_DURATION() external view returns (uint256);

    function VOTE_DIFFERENTIAL() external view returns (uint256);

    function MINIMUM_QUORUM() external view returns (uint256);

    function ONE_HUNDRED_WITH_PRECISION() external view returns (uint256);

    function isPowerEnough(
        IGovernance governance,
        address user,
        uint256 blockNumber
    ) external view returns (bool);

    function validateCreatorOfProposal(
        IGovernance governance,
        address user,
        uint256 blockNumber
    ) external view returns (bool);

    function validateProposalCancellation(
        IGovernance governance,
        address user
    ) external view returns (bool);

    function validateCreateOfMarket(
        IGovernance governance,
        address user
    ) external view returns (bool);

    function isProposalPassed(
        IGovernance governance,
        uint256 proposalId
    ) external view returns (bool);

    function isQuorumValid(
        IGovernance governance,
        uint256 proposalId
    ) external view returns (bool);

    function isProposalOverGracePeriod(
        IGovernance governance,
        uint256 proposalId
    ) external view returns (bool);

    function getMinimumPowerNeeded(
        IGovernance governance,
        uint256 blockNumber
    ) external view returns (uint256);
}
