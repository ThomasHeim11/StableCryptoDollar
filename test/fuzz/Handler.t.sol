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

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(SCDEngine _scdEngine, StableCryptoDollar _scd) {
        scde = _scdEngine;
        scd = _scd;

        address[] memory collateralTokens = scde.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function mintScd(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        (uint256 totalScdMinted, uint256 collateralValueInUsd) = scde.getAccountInformation(msg.sender);
        
        int256 maxScdToMint = (collateralValueInUsd / 2) - totalScdMinted;
        if(maxScdToMint < 0) {
            return;
        }
        amount = bound(amount, 0, maxScdToMint);
            if (amount == 0) {
                return;
            }
        vm.startPrank(msg.sender);
        scde.mintSCD(amount);
        vm.stopPrank();
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(scde), amountCollateral);
        scde.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToReedem = scde.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToReedem);
        if (amountCollateral == 0) {
            return;
        }
        scde.redeemCollateral(address(collateral), amountCollateral);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
