// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeploySCD} from "../../script/DeploySCD.s.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";
import {HelperConfig} from "../../src/HelperConfig.sol";

contract InvariantsTest is StdInvariant, Test {
    DeploySCD deployer;
    SCDEngine scde;
    StableCryptoDollar scd;
    HelperConfig config; 

    function setUp() external {
        deployer = new DeploySCD();
        (scd, scde, config) = deployer.run();

    }

}