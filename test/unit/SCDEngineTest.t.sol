// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeploySCD} from "../../script/DeploySCD.s.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";

contract SCDEngineTest is Test {
    DeploySCD deployer;
    StableCryptoDollar scd;
    SCDEngine scde;

    function setUp() public {
        deployer = new DeploySCD();
        (scd, scde) = deployer.run();
    }
}