// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeploySCD} from "../../script/DeploySCD.s.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract SCDEngineTest is Test {
    DeploySCD deployer;
    StableCryptoDollar scd;
    SCDEngine scde;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() public {
        deployer = new DeploySCD();
        (scd, scde, config) = deployer.run();
        (ethUsdPriceFeed, , weth, , ) = config.activeNetworkConfig();
    }

    //////////////////////
    // Price Test Cases //
    //////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = scde.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    ////////////////////////////
    // DepositCollateral Test //
    ////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(address(scde)), AMOUNT_COLLATERAL);

        vm.expectRevert(SCDEngine.SCDEngine__NeedsMoreThanZero);
        scde.depositCollateral(weth, 0);
        vm.stopPrank();

    }
    
}
