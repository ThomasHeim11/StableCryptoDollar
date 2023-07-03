// Commented out for now until revert on fail == false per function customization is implemented

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// import {Test} from "forge-std/Test.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

// import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
// import {SCDEngine, AggregatorV3Interface} from "../../../src/SCDEngine.sol";
// import {StableCryptoDollar} from "../../../src/StableCryptoDollar.sol";
// import {Randomish, EnumerableSet} from "../Randomish.sol";
// import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
// import {console} from "forge-std/console.sol";

// contract ContinueOnRevertHandler is Test {
//     using EnumerableSet for EnumerableSet.AddressSet;
//     using Randomish for EnumerableSet.AddressSet;

//     // Deployed contracts to interact with
//     SCDEngine public scdEngine;
//     StableCryptoDollar public scd;
//     MockV3Aggregator public ethUsdPriceFeed;
//     MockV3Aggregator public btcUsdPriceFeed;
//     ERC20Mock public weth;
//     ERC20Mock public wbtc;

//     // Ghost Variables
//     uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

//     constructor(SCDEngine _scdEngine, StableCryptoDollar _scd) {
//         scdEngine = _scdEngine;
//         scd = _scd;

//         address[] memory collateralTokens = scdEngine.getCollateralTokens();
//         weth = ERC20Mock(collateralTokens[0]);
//         wbtc = ERC20Mock(collateralTokens[1]);

//         ethUsdPriceFeed = MockV3Aggregator(
//             scdEngine.getCollateralTokenPriceFeed(address(weth))
//         );
//         btcUsdPriceFeed = MockV3Aggregator(
//             scdEngine.getCollateralTokenPriceFeed(address(wbtc))
//         );
//     }

//     // FUNCTOINS TO INTERACT WITH

//     ///////////////
//     // SCDEngine //
//     ///////////////
//     function mintAndDepositCollateral(
//         uint256 collateralSeed,
//         uint256 amountCollateral
//     ) public {
//         amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         collateral.mint(msg.sender, amountCollateral);
//         scdEngine.depositCollateral(address(collateral), amountCollateral);
//     }

//     function redeemCollateral(
//         uint256 collateralSeed,
//         uint256 amountCollateral
//     ) public {
//         amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         scdEngine.redeemCollateral(address(collateral), amountCollateral);
//     }

//     function burnScd(uint256 amountScd) public {
//         amountScd = bound(amountScd, 0, scd.balanceOf(msg.sender));
//         scd.burn(amountScd);
//     }

//     function mintScd(uint256 amountScd) public {
//         amountScd = bound(amountScd, 0, MAX_DEPOSIT_SIZE);
//         scd.mint(msg.sender, amountScd);
//     }

//     function liquidate(
//         uint256 collateralSeed,
//         address userToBeLiquidated,
//         uint256 debtToCover
//     ) public {
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         scdEngine.liquidate(
//             address(collateral),
//             userToBeLiquidated,
//             debtToCover
//         );
//     }

//     /////////////////////////////
//     // DecentralizedStableCoin //
//     /////////////////////////////
//     function transferScd(uint256 amountScd, address to) public {
//         amountScd = bound(amountScd, 0, scd.balanceOf(msg.sender));
//         vm.prank(msg.sender);
//         scd.transfer(to, amountScd);
//     }

//     /////////////////////////////
//     // Aggregator //
//     /////////////////////////////
//     function updateCollateralPrice(
//         uint128 newPrice,
//         uint256 collateralSeed
//     ) public {
//         // int256 intNewPrice = int256(uint256(newPrice));
//         int256 intNewPrice = 0;
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         MockV3Aggregator priceFeed = MockV3Aggregator(
//             scdEngine.getCollateralTokenPriceFeed(address(collateral))
//         );

//         priceFeed.updateAnswer(intNewPrice);
//     }

//     /// Helper Functions
//     function _getCollateralFromSeed(
//         uint256 collateralSeed
//     ) private view returns (ERC20Mock) {
//         if (collateralSeed % 2 == 0) {
//             return weth;
//         } else {
//             return wbtc;
//         }
//     }

//     function callSummary() external view {
//         console.log("Weth total deposited", weth.balanceOf(address(scdEngine)));
//         console.log("Wbtc total deposited", wbtc.balanceOf(address(scdEngine)));
//         console.log("Total supply of SCD", scd.totalSupply());
//     }
// }