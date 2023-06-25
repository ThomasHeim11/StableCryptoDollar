// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

/**  
@title DSCEngine
@author Thomas Heim
@notice The SCDEngine contract serves as the core component of the Decentralized Stablecoin system.
It is designed to maintain a 1 token == $1 peg at all times, providing stability and functioning as a stablecoin.
This system possesses the following properties:
- Exogenously Collateralized
- Dollar Pegged
- Algorithmically Stable
It bears resemblance to DAI; however, it lacks governance, fees, and relies solely on WETH and WBTC as collateral.
@notice This contract handles all the essential functionalities of the Decentralized Stablecoin system,
including minting and redeeming SCD, as well as depositing and withdrawing collateral.
It draws inspiration from the MakerDAO DSS system.
*/

contract SCDEngine {
    function depositCollateralAndMintSCD() external {}

    function redeemCollateralForSCD() external {}

    function brunSCD() extenral {}
}