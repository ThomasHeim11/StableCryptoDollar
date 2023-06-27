// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script{
    struct NewtworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
    }
}