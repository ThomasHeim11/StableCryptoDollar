// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {StableCryptoDollar} from "../src/StableCryptoDollar.sol";
import {SCDEngine} from "../src/SCDEngine.sol";

contract DeploySCD is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StableCryptoDollar, SCDEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        StableCryptoDollar scd = new StableCryptoDollar();
        SCDEngine scdEngine = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(scd)
        );
        scd.transferOwnership(address(scdEngine));
        vm.stopBroadcast();
        return (scd, scdEngine, helperConfig);
    }
}