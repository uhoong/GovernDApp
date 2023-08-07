// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IVote{
    struct Vote{
        bool support;
        uint248 votingPower;
    }

    function isProposalPassed() external view returns(bool);
}