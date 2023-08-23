// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Target{
    uint256 public value;

    constructor(){
        value = 5;
    }

    function setTargetWithoutValue(uint256 newTarget) public returns(uint256){
        value = newTarget;
        return value;
    }

    function setTargetWithValue(uint256 newTarget) public payable returns(uint256){
        value = newTarget;
        return value;
    }
}