// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReview{
    function REVIEW_DURATION() external view returns(uint256);

    function createReview(uint256 proposalId,uint256 startBlock,uint256 endBlock) external returns(address);
}

