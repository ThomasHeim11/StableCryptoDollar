// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeploySCD} from "../../../script/DeploySCD.s.sol";
import {SCDEngine} from "../../../src/SCDEngine.sol";
import {StableCryptoDollar} from "../../../src/StableCryptoDollar.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StopOnRevertHandler} from "./StopOnRevertHandler.t.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract StopOnRevertInvariants is StdInvariant, Test {
    SCDEngine public scde;
    StableCryptoDollar public scd;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public constant USER = address(1);
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    StopOnRevertHandler public handler;

    function setUp() external {
        DeploySCD deployer = new DeploySCD();
        (scd, scde, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
        handler = new StopOnRevertHandler(scde, scd);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars() public view {
        uint256 totalSupply = scd.totalSupply();
        uint256 wethDeposted = ERC20Mock(weth).balanceOf(address(scde));
        uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(scde));

        uint256 wethValue = scde.getUsdValue(weth, wethDeposted);
        uint256 wbtcValue = scde.getUsdValue(wbtc, wbtcDeposited);

        console.log("wethValue: %s", wethValue);
        console.log("wbtcValue: %s", wbtcValue);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersCantRevert() public view {
        scde.getAdditionalFeedPrecision();
        scde.getCollateralTokens();
        scde.getLiquidationBonus();
        scde.getLiquidationBonus();
        scde.getLiquidationThreshold();
        scde.getMinHealthFactor();
        scde.getPrecision();
        scde.getScd();
        // scde.getTokenAmountFromUsd();
        // scde.getCollateralTokenPriceFeed();
        // scde.getCollateralBalanceOfUser();
        // getAccountCollateralValue();
    }
}
