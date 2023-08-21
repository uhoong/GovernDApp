// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReview} from "../interfaces/IReview.sol";
import {IVoteFactory} from "../interfaces/factory/IVoteFactory.sol";
import {IVote} from "../interfaces/factory/IVote.sol";
import {IGovernance} from "../interfaces/IGovernance.sol";
import {IConditionalTokens} from "../interfaces/market/IConditionalTokens.sol";

contract Review is IReview {
    uint256 public REVIEW_DURATION = 7200;

    IVoteFactory public voteFactory;
    IConditionalTokens public ct;
    address oracle;

    // mapping (uint256 => bool) public reviewCreated;

    constructor(address _voteFactory,address _ct,address _oracle) {
        voteFactory = IVoteFactory(_voteFactory);
        ct = IConditionalTokens(_ct);
        oracle = _oracle;
    }

    function createReview(
        address governance,
        uint256 proposalId
    ) public{
        IGovernance.ProposalInfo memory proposalInfo = IGovernance(governance).getProposalById(proposalId);
        if(proposalInfo.marketReview){
            ct.prepareCondition(oracle,bytes32(proposalId),2);
            // TODO：初始化交易市场
        }else{
            voteFactory.createVote(governance, proposalId);
        }
    }

    //参数直接传入合约地址是作为底层函数，后续可以开发外围合约，在外围合约中计算地址
    function getReviewResult(address reviewAddr) public view returns (bool) {
        return IVote(reviewAddr).isProposalPassed();
    }

    function isProposalPassed(
        address governance,
        uint256 proposalId
    ) external view returns (bool) {
        address reviewAddr = voteFactory.getAddress(governance, proposalId);
        return IVote(reviewAddr).isProposalPassed();
    }
}
