// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernToken {
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    event DelegateVotesChanged(
        address indexed delegate,
        uint previousBalance,
        uint newBalance
    );

    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    function getVotingPowerAt(
        address account,
        uint blockNumber
    ) external view returns (uint256);

    function getCurrentVotingPower(
        address account
    ) external view returns (uint256);
}
