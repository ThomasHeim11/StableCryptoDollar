// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    SCDEngine scde;
    StableCryptoDollar scd;

    ERC20Mock weth;
    ERC20Mock wbtc;

    constructor(SCDEngine _scdEngine, StableCryptoDollar _scd) {
        scde = _scdEngine;
        scd = _scd;
        
        address[] memory collateralTokens = scde.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function depositCollateral (uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        scde.depositCollateral(address(collateral), amountCollateral);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns  (ERC20Mock) {
        if(collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}