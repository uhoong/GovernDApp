// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReview {
    function REVIEW_DURATION() external view returns (uint256);

    function createReview(
        address governance,
        uint256 proposalId
    ) external;

    function isProposalPassed(
        address governance,
        uint256 proposalId
    ) external view returns (bool);
}
