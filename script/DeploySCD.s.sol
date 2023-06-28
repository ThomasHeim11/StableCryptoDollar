// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {StableCryptoDollar} from "../src/StableCryptoDollar.sol";
import {SCDEngine} from "../src/SCDEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySCD is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StableCryptoDollar, SCDEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

       (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc,
       uint256 deployerKey) =
        config.activeNetworkConfig();

       tokenAddresses = [weth, wbtc];
       priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

       vm.startBroadcast(deployerKey);
       StableCryptoDollar scd = new StableCryptoDollar();
       SCDEngine engine = new SCDEngine(tokenAddresses, priceFeedAddresses, address(scd));

       scd.transferOwnership(address(engine));
       vm.stopBroadcast();
       return (scd, engine, config);
    }
}