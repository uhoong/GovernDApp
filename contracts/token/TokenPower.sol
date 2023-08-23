// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TimeTokenPower {
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

    struct TimeToken {
        uint256 stakeFromBlock;
        uint256 amount;
        bool locked;
        uint256 lockFromBlock;
        uint256 lockTime;
    }

    IERC20 public immutable PanGu;

    uint256 public immutable lockTimeLimit;

    uint256 public totalVotingSupplyAt;

    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    mapping(address => uint256) public numCheckpoints;

    mapping(address => address) public delegates;

    mapping(address => uint256) public power; //类似于 balance，并不用于直接计算投票权力

    mapping(address => uint256) public lockedPower;

    mapping(address => uint256) public tokenIds;

    mapping(address => mapping(uint256 => TimeToken)) public timeTokens;

    constructor(address pangu, uint256 _lockTimeLimit) {
        PanGu = IERC20(pangu);
        lockTimeLimit = _lockTimeLimit;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "INVALID_AMOUNT");
        PanGu.transferFrom(msg.sender, address(this), amount);
        uint256 tokenId = tokenIds[msg.sender];
        tokenIds[msg.sender] += 1;
        _stake(msg.sender, amount, tokenId);
    }

    function stackById(uint256 amount, uint256 tokenId) public {
        require(amount > 0, "INVALID_AMOUNT");
        TimeToken storage timeToken = timeTokens[msg.sender][tokenId];
        require(timeToken.amount == 0, "TIMETOKEN_EXIST");
        PanGu.transferFrom(msg.sender, address(this), amount);
        _stake(msg.sender, amount, tokenId);
    }

    function _stake(address user, uint256 amount, uint256 tokenId) public {
        timeTokens[user][tokenId] = TimeToken(
            block.number,
            amount,
            false,
            0,
            0
        );
    }

    function depositById(uint256 amount, uint256 tokenId) public {
        TimeToken storage timeToken = timeTokens[msg.sender][tokenId];
        require(timeToken.amount > amount, "INVALID_AMOUNT");
        if (timeToken.locked) {
            _unlock(msg.sender, tokenId);
        }
        timeToken.amount -= amount;

        PanGu.transfer(msg.sender, amount);
    }

    function lock(uint256 tokenId, uint256 lockTime, address delegatee) public {
        _lock(msg.sender, tokenId, lockTime, delegatee);
    }

    function _lock(
        address user,
        uint256 tokenId,
        uint256 lockTime,
        address delegatee
    ) public {
        TimeToken storage timeToken = timeTokens[user][tokenId];
        require(timeToken.amount > 0, "NULL_TIMETOKEN");
        require(lockTime < lockTimeLimit, "INVALID_LOCKTIME");
        require(!timeToken.locked, "TIMETOKEN_LOCKED");
        timeToken.locked = true;
        timeToken.lockFromBlock = block.number;
        timeToken.lockTime = lockTime;
        power[user] +=
            timeToken.amount *
            (block.number - timeToken.stakeFromBlock + 2 * lockTime); //只记录锁定时长不够，还需要记录锁定区块高度
        _delegate(user, delegatee);
    }

    function unlock(uint256 tokenId) public {
        _unlock(msg.sender, tokenId);
    }

    function _unlock(address user, uint256 tokenId) public {
        TimeToken storage timeToken = timeTokens[user][tokenId];
        require(timeToken.amount > 0, "NULL_TIMETOKEN");
        require(
            timeToken.lockFromBlock + timeToken.lockTime > block.number,
            "LOCKING"
        );
        require(timeToken.locked, "ALREADY_UNLOCK");
        timeToken.locked = false;
        power[user] -=
            timeToken.lockFromBlock -
            timeToken.stakeFromBlock +
            timeToken.lockTime *
            2;
        _moveDelegates(user, delegates[user], timeToken.amount);
    }

    function getNotZeroIds(
        address user
    ) public view returns (uint256[] memory validIds) {
        uint256 k = 0;
        for (uint256 i = 0; i < tokenIds[user]; i++) {
            TimeToken storage timeToken = timeTokens[user][i];
            if (timeToken.amount != 0) {
                validIds[k] = i;
                k++;
            }
        }
    }

    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint256 delegatorPower = power[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorPower);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0
                    ? checkpoints[srcRep][srcRepNum - 1].votes
                    : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0
                    ? checkpoints[dstRep][dstRepNum - 1].votes
                    : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal {
        uint256 blockNumber = block.number;
        if (
            nCheckpoints > 0 &&
            checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(
                blockNumber,
                newVotes
            );
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function getCurrentVotingPower(
        address user
    ) external view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[user];
        return nCheckpoints > 0 ? checkpoints[user][nCheckpoints - 1].votes : 0;
    }

    function getVotingPowerAt(
        address user,
        uint blockNumber
    ) public view returns (uint256) {
        require(
            blockNumber < block.number,
            "BLOCKNUMBER_INVALID"
        );

        uint256 nCheckpoints = numCheckpoints[user];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[user][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[user][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[user][0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[user][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[user][lower].votes;
    }
}
