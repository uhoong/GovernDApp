// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IGovernance.sol";

interface IValidator {
    function validateCreatorOfProposal(
        IGovernance governance,
        address user
    ) external view returns (bool);

    function validateProposalCancellation(
        IGovernance governance,
        address user
    ) external view returns (bool);

    function isProposalPassed(
        IGovernance governance,
        uint256 proposalId
    ) external view returns (bool);

    function isProposalOverGracePeriod(
        IGovernance governance,
        uint256 proposalId
    ) external view returns (bool);
}
