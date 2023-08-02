// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {TimeTokenVote} from "./TimeTokenVote.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VoteFactory {
    TimeTokenVote public immutable timeTokenVoteImplementation;

    constructor() {
        timeTokenVoteImplementation = new TimeTokenVote();
    }

    function createVote(uint256 proposalId) public returns (address) {
        return address(createTimeTokenVote(proposalId));
    }

    function createTimeTokenVote(
        uint256 salt
    ) public returns (TimeTokenVote ret) {
        address addr = getAddress(salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return TimeTokenVote(payable(addr));
        }
        ret = TimeTokenVote(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(timeTokenVoteImplementation),
                    abi.encodeCall(TimeTokenVote.initialize, ())
                )
            )
        );
    }

    function getAddress(uint256 salt) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(timeTokenVoteImplementation),
                            abi.encodeCall(TimeTokenVote.initialize, ())
                        )
                    )
                )
            );
    }

    // function createTimeTokenVote(address _owner,address _verifyingSigner,address _checkSigProxy,uint256 salt) public returns (VerifyingPaymaster ret) {
    //     address addr = getAddress(_owner,_verifyingSigner,_checkSigProxy, salt);
    //     uint codeSize = addr.code.length;
    //     if (codeSize > 0) {
    //         return VerifyingPaymaster(payable(addr));
    //     }
    //     ret = VerifyingPaymaster(payable(new ERC1967Proxy{salt : bytes32(salt)}(
    //             address(paymasterImplementation),
    //             abi.encodeCall(VerifyingPaymaster.initialize, (_owner,_verifyingSigner,_checkSigProxy))
    //         )));
    // }

    // function getAddress(address _owner,address _verifyingSigner,address _checkSigProxy,uint256 salt) public view returns (address) {
    //     return Create2.computeAddress(bytes32(salt), keccak256(abi.encodePacked(
    //             type(ERC1967Proxy).creationCode,
    //             abi.encode(
    //                 address(paymasterImplementation),
    //                 abi.encodeCall(VerifyingPaymaster.initialize, (_owner,_verifyingSigner,_checkSigProxy))
    //             )
    //         )));
    // }
}
