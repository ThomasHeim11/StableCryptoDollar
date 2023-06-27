// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {StableCryptoDollar} from "../src/StableCryptoDollar.sol";

contract DeploySCD is Script {
    function run() external returns(StableCryptoDollar, SCDEngine ) {}
}