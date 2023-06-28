// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeploySCD} from "../../script/DeploySCD.s.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract SCDEngineTest is Test {
    DeploySCD deployer;
    StableCryptoDollar scd;
    SCDEngine scde;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    function setUp() public {
        deployer = new DeploySCD();
        (scd, scde, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
    }

    //////////////////////
    // Price Test Cases //
    //////////////////////

    function testGetUsdValue () public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 3000e18;
        uint256 ectualUsd = scde.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, ectualUsd);
    }
}