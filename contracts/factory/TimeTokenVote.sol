// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract TimeTokenVote is Initializable {
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        _initialize();
    }

    function _initialize() internal {}


}