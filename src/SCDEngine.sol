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

contract SCDEngine is ReentrancyGuard {
    ///////////////////
    // Errors       //
    ///////////////////
    error SCDEngine__NeedsMoreThanZero();
    error SCDEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
    error SCDEngine__NotAllowedToken();
    error SCDEngine__TransferFromFailed();

    //////////////////////
    // State Variables  //
    //////////////////////
    mapping(address token => address s_priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256)) private s_collateralBalances;
    mapping(address user => uint256 amountSCDEMinted) private s_SCDMinted;

    StableCryptoDollar private immutable i_SCDE;

    //////////////////////
    // Events           //
    //////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    ///////////////////
    // Modifiers     //
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert SCDEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeed[token] == address(0)) {
            revert SCDEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////////
    // Funtions     //
    ///////////////////
    constructor(address[] memory tokenAddress, address[] memory priceFeedAddresses, address SCDAddress) {
        if (tokenAddress.lenght != priceFeedAddresses.length) {
            revert SCDEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
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
        isAllowedToken(tokenCollateralAddress)
        nonReentrant

    {
        s_collateralBalances[mag.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool succes = IERC2(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!succes) {
            revert SCDEngine__TransferFromFailed();
        }
    }

    function redeemCollateralForSCD external {}

    function redeemColleteral() external {}

    function mintSCD(uint256 amountDscToMint) external moreThanZero(amountSCDToMint) nonReentrant {
        s_SCDMinted[msg.sender] += amountSCDToMint;
        revertIfHealthFactorIsBroken(msg.sender);

    }

    function brunSCD() extenral {}

    function liquidate() external {}

    function getHelathFactor() external view {}

    ////////////////////////////////////////
    // Private & Internal View Functions //
    ///////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalSCDMinted, uint256 collateralValueInUsd) 
        {
            totalSCDMinted = s_SCDMinted[user];
            collateralValueInUsd = getAccountCollateralValue(user);
        }


    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalSCDMinted, uitn256 collateralValueInUsd) = _getAccountInformation(user);
    }


    function _revertIfHealthFactorIsBroken(address user) private view {}
}
