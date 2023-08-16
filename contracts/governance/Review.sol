// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReview} from "../interfaces/IReview.sol";
import {IVoteFactory} from "../interfaces/factory/IVoteFactory.sol";
import {IVote} from "../interfaces/factory/IVote.sol";

contract Review is IReview{
    uint256 public REVIEW_DURATION = 7200;

    IVoteFactory public voteFactory;

    // mapping (uint256 => bool) public reviewCreated;

    constructor(address _voteFactory){
        voteFactory = IVoteFactory(_voteFactory);
    }

    function createReview(address governance,uint256 proposalId) public returns(address){
        // require(!reviewCreated[proposalId],"REVIEW_CREATED");
        // reviewCreated[proposalId]=true;
        return voteFactory.createVote(governance,proposalId);
    }

    //参数直接传入合约地址是作为底层函数，后续可以开发外围合约，在外围合约中计算地址
    function getReviewResult(address reviewAddr) public view returns(bool){
        return IVote(reviewAddr).isProposalPassed();
    }

    function isProposalPassed(address governance,uint256 proposalId) external view returns(bool){
        address reviewAddr = voteFactory.getAddress(governance,proposalId);
        return IVote(reviewAddr).isProposalPassed();
    }
}