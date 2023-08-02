// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract TimeTokenSuit{
    struct TimeToken {
        uint32 blocknumber;
        uint256 amount;
    }

    mapping(address=>uint256) public stackTop;

    mapping(address=>mapping(uint256=>TimeToken)) public timeStack;

    function _removeTimeToken(address addr,uint256 amount) internal{
        uint256 top = stackTop[addr]-1;
        while(amount>0){
            TimeToken storage timeToken = timeStack[addr][top];
            if(timeToken.amount>amount){
                timeToken.amount-=amount;
                amount=0;
            }else{
                amount-=timeToken.amount;
                top--;
            }
        }
        stackTop[addr]=top+1;
    }

    function _addTimeToken(address addr,uint256 amount) internal{
        uint256 top = stackTop[addr];
        timeStack[addr][top] = TimeToken(uint32(block.number),amount);
        stackTop[addr]=top+1;
    }
}