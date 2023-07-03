// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeploySCD} from "../../script/DeploySCD.s.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvariantsTest is StdInvariant, Test {
    DeploySCD deployer;
    SCDEngine scde;
    StableCryptoDollar scd;
    HelperConfig config; 
    address weth;
    address wbtc;


    function setUp() external {
        deployer = new DeploySCD();
        (scd, scde, config) = deployer.run();
        (,, weth, wbtc, ) = config.activeNetworkConfig();
        targetContract(address(scde));

    }

    function invarient_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = scd.totalSupply();
        uint256 totalWethDepositet = IERC20(weth).balanceOf(address(scde));
        uint256 totalWbtcDepositet = IERC20(wbtc).balanceOf(address(scde));

        uint256 wethValue = scde.getUsdValue(weth, totalWethDepositet);
        uint256 wbtcValue = scde.getUsdValue(wbtc, totalWbtcDepositet);

        assert (wethValue + wbtcValue > totalSupply);
    }

}