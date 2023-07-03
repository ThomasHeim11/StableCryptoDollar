// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";

contract Handler is Test {
    SCDEngine scde;
    StableCryptoDollar scd;

    constructor(SCDEngine _scdEngine, StableCryptoDollar _scd) {
        scde = _scdEngine;
        scd = _scd;
    }
}
