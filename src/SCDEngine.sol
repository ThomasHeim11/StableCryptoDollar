// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableCryptoDollar} from "./StableCryptoDollar.sol";

/**
 * @title DSCEngine
 * @author Thomas Heim
 * @notice The SCDEngine contract serves as the core component of the Decentralized Stablecoin system.
 * It is designed to maintain a 1 token == $1 peg at all times, providing stability and functioning as a stablecoin.
 * This system possesses the following properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 * It bears resemblance to DAI; however, it lacks governance, fees, and relies solely on WETH and WBTC as collateral.
 * @notice This contract handles all the essential functionalities of the Decentralized Stablecoin system,
 * including minting and redeeming SCD, as well as depositing and withdrawing collateral.
 * It draws inspiration from the MakerDAO DSS system.
 */

contract SCDEngine {
    ///////////////////
    // Errors       //
    ///////////////////
    error SCDEngine__NeedsMoreThanZero();
    error SCDEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
    error SCDEngine__NotAllowedToken();

    //////////////////////
    // State Variables  //
    //////////////////////
    mapping(address token => address s_priceFeed) private s_priceFeeds;

    StableCryptoDollar private immutable i_SCDE;

    ///////////////////
    // Modifiers     //
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert SCDEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token){
        if(s_priceFeed[token] == address(0)){
            revert SCDEngine__NotAllowedToken();
        }
        _; 

    }

    ///////////////////
    // Funtions     //
    ///////////////////
    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddresses,
        address SCDAddress
    ) {
        if(tokenAddress.lenght != priceFeedAddresses.length){
            revert SCDEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
        }
        for(uint256 i = 0; i < tokenAddress.length; i++){
            s_priceFeeds[tokenAddress[i]] = priceFeedAddresses[i];
        }
        i_SCDE = StableCryptoDollar(SCDAddress);
    }

    ////////////////////////
    // External Functions //
    ///////////////////////

    function depositCollateralAndMintSCD() external {}

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
    {}

    function redeemCollateralForSCD(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) 
    
    external 
    moreThanZero(amountCollateral)
    isAllowedToken (tokenCollateralAddress) 
    nonReentrant
    
    {}

    function redeemColleteral() external {}

    function mintSCD() external {}

    function brunSCD() extenral {}

    function liquidate() external {}

    function getHelathFactor() external view {}
}
