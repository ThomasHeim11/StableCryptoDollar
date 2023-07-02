// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeeploySCD} from "../../script/DeploySCD.s.sol";
import {SCDEngine} from "../../script/SCDEngine.s.sol";

contract InvariantsTest is StdInvariant, Test {
    function setUp() external {
        DeploySCD deployer;
        
    }
}