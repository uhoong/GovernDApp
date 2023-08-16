// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {IGovernance} from "../interfaces/IGovernance.sol";
import {IVote} from "../interfaces/factory/IVote.sol";
import {IVotingStrategy} from "../interfaces/IVotingStrategy.sol";


contract TimeTokenVote is Initializable, IVote {
    uint256 public forVotes;
    uint256 public againstVotes;
    IGovernance public governance;

    mapping(address => Vote) public votes;

    function initialize(
        address _governance
    ) public initializer {
        _initialize(_governance);
    }

    function _initialize(
        address _governance
    ) internal {
        governance = IGovernance(_governance);
    }

    function castVote(uint256 proposalId, bool support) public {
        _castVote(msg.sender, proposalId, support);
    }

    function _castVote(
        address voter,
        uint256 proposalId,
        bool support
    ) internal {
        require(
            governance.getProposalState(proposalId) == IGovernance.ProposalState.Active,
            "VOTING_CLOSED"
        );
        IGovernance.ProposalInfo memory proposal = governance.getProposalById(proposalId);
        // Proposal storage proposal = _proposals[proposalId];
        Vote storage vote = votes[voter];

        require(vote.votingPower == 0, "VOTE_ALREADY_SUBMITTED");

        uint256 votingPower = IVotingStrategy(proposal.strategy)
            .getVotingPowerAt(voter, proposal.startBlock);

        if (support) {
            forVotes = forVotes + votingPower;
        } else {
            againstVotes = againstVotes + votingPower;
        }

        vote.support = support;
        vote.votingPower = votingPower;
    }

    function isProposalPassed() public view returns (bool) {
        return forVotes>againstVotes;
    }

    // function isQuorumValid() public view override returns (bool) {
    //     IGovernance.ProposalInfo memory proposal = governance
    //         .getProposalById(proposalId);
    //     uint256 votingSupply = IGovernanceStrategy(proposal.strategy)
    //         .getTotalVotingSupplyAt(proposal.startBlock);

    //     return forVotes >= getMinimumVotingPowerNeeded(votingSupply);
    // }

    // function getMinimumVotingPowerNeeded(
    //     uint256 votingSupply
    // ) public view override returns (uint256) {
    //     return votingSupply*MINIMUM_QUORUM/ONE_HUNDRED_WITH_PRECISION;
    // }

    // function isVoteDifferentialValid(
    //     IGovernance governance,
    //     uint256 proposalId
    // ) public view override returns (bool) {
    //     IGovernance.ProposalInfo memory proposal = governance.getProposalById(
    //         proposalId
    //     );
    //     uint256 votingSupply = IGovernanceStrategy(proposal.strategy)
    //         .getTotalVotingSupplyAt(proposal.startBlock);
    //     return
    //         ((forVotes * ONE_HUNDRED_WITH_PRECISION) / votingSupply) >
    //         (againstVotes * ONE_HUNDRED_WITH_PRECISION) /
    //             votingSupply +
    //             VOTE_DIFFERENTIAL;
    // }
}
