// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {IGovernacne} from "../interfaces/IGovernacne.sol";
import {IVote} from "../interfaces/factory/IVote.sol";
import {IGovernToken} from "../interfaces/token/IGovernToken.sol";
// import {IVotingStrategy} from "../interfaces/IVotingStrategy.sol";

contract TimeTokenVote is Initializable, IVote {
    uint256 public forVotes;
    uint256 public againstVotes;
    uint256 public startBlock;
    uint256 public endBlock;
    IGovernacne public governance;
    IGovernToken public token;

    mapping(address => Vote) public votes;

    function initialize(
        address _governance,
        address _token,
        uint256 _startBlock,
        uint256 _endBlock
    ) public initializer {
        _initialize(_governance, _token,_startBlock, _endBlock);
    }

    function _initialize(
        address _governance,
        address _token,
        uint256 _startBlock,
        uint256 _endBlock
    ) internal {
        governance = IGovernacne(_governance);
        token = IGovernToken(_token);
        startBlock = _startBlock;
        endBlock = _endBlock;
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
            governance.getProposalState(proposalId) == ProposalState.Active,
            "VOTING_CLOSED"
        );
        // Proposal storage proposal = _proposals[proposalId];
        Vote storage vote = votes[voter];

        require(vote.votingPower == 0, "VOTE_ALREADY_SUBMITTED");

        uint256 votingPower = IVotingStrategy(proposal.strategy)
            .getVotingPowerAt(voter, startBlock);

        if (support) {
            forVotes = forVotes + votingPower;
        } else {
            againstVotes = againstVotes + votingPower;
        }

        vote.support = support;
        vote.votingPower = uint248(votingPower);
    }

    function isProposalPassed() public view returns (bool) {
        return (isQuorumValid() && isVoteDifferentialValid());
    }

    function isQuorumValid() public view override returns (bool) {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governance
            .getProposalById(proposalId);
        uint256 votingSupply = IGovernanceStrategy(proposal.strategy)
            .getTotalVotingSupplyAt(proposal.startBlock);

        return forVotes >= getMinimumVotingPowerNeeded(votingSupply);
    }

    function isVoteDifferentialValid(
        IAaveGovernanceV2 governance,
        uint256 proposalId
    ) public view override returns (bool) {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governance
            .getProposalById(proposalId);
        uint256 votingSupply = IGovernanceStrategy(proposal.strategy)
            .getTotalVotingSupplyAt(proposal.startBlock);

        return (proposal.forVotes.mul(ONE_HUNDRED_WITH_PRECISION).div(
            votingSupply
        ) >
            proposal
                .againstVotes
                .mul(ONE_HUNDRED_WITH_PRECISION)
                .div(votingSupply)
                .add(VOTE_DIFFERENTIAL));
    }
}
