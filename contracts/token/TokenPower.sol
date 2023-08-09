// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenPower{

    struct TimeToken {
        uint256 blocknumber;
        uint256 amount;
        bool locked;
    }

    IERC20 public immutable PanGu;

    uint256 public immutable lockTimeLimit;

    mapping(address=>uint256) public lockedPower;

    mapping(address=>uint256) public tokenIds;

    mapping(address=>mapping(uint256=>TimeToken)) public timeTokens;

    mapping(address=>mapping(uint256=>uint256)) public lockedTimes;


    constructor(address pangu,uint256 _lockTimeLimit){
        PanGu = IERC20(pangu);
        lockTimeLimit = _lockTimeLimit;
    }

    function stake(uint256 amount) public{
        require(amount>0,"INVALID_AMOUNT");
        PanGu.transferFrom(msg.sender,address(this),amount);
        uint256 tokenId = tokenIds[msg.sender];
        tokenIds[msg.sender]+=1;
        _stake(msg.sender,amount,tokenId);
    }

    function stackById(uint256 amount,uint256 tokenId) public{
        require(amount>0,"INVALID_AMOUNT");
        TimeToken storage timeToken = timeTokens[msg.sender][tokenId];
        require(timeToken.amount==0,"TIMETOKEN_EXIST");
        PanGu.transferFrom(msg.sender,address(this),amount);
        _stake(msg.sender,amount,tokenId);
    }

    function _stake(address user,uint256 amount,uint256 tokenId) public{
        timeTokens[user][tokenId] = TimeToken(block.number,amount,false);
    }

    function depositById(uint256 amount,uint256 tokenId) public{
        TimeToken storage timeToken = timeTokens[msg.sender][tokenId];
        require(timeToken.amount>amount,"INVALID_AMOUNT");
        if(timeToken.locked){
            _unlock(msg.sender,tokenId);
        }
        timeToken.amount-=amount;
        
        PanGu.transfer(msg.sender,amount);
    }

    function lock(uint256 tokenId,uint256 lockTime) public{
        TimeToken storage timeToken = timeTokens[msg.sender][tokenId];
        require(timeToken.amount>0,"NULL_TIMETOKEN");
        require(lockTime<lockTimeLimit,"INVALID_LOCKTIME");
        require(!timeToken.locked,"TIMETOKEN_LOCKED");
        timeToken.locked = true;
        lockedTimes[msg.sender][tokenId]=timeToken.blocknumber+lockTime;
    }

    function unlock(uint256 tokenId) public{
        _unlock(msg.sender,tokenId);
    }

    function _unlock(address user,uint256 tokenId)  public{
        require(block.number>lockedTimes[user][tokenId],"LOCKING");
        TimeToken storage timeToken = timeTokens[user][tokenId];
        require(timeToken.amount>0,"NULL_TIMETOKEN");
        require(timeToken.locked,"UNLOCK");
        timeToken.locked=false;
    }

    function getNotZeroIds(address user) public view returns (uint256[] memory validIds) {
        uint256 k=0;
        for(uint256 i=0;i<tokenIds[user];i++){
            TimeToken storage timeToken = timeTokens[user][i];
            if(timeToken.amount!=0){
                validIds[k]=i;
                k++;
            }
        }
    }
}