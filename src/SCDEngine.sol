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
    error SCDEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
    error SCDEngine__NeedsMoreThanZero();
    error SCDEngine__TokenNotAllowed(address token);
    error SCDEngine__TransferFromFailed();
    error SCDEngine__BreakHealthFactor(uint256 healthFactor);
    error SCDEngine__MintFailed();
    error SCDEngine__HealthFactorOk();
    error SCDEngine__HealthFactorNotImproved();

    ///////////////////
    // Types         //
    ///////////////////
    using OracleLib for AggregatorV3Interface;

    //////////////////////
    // State Variables  //
    //////////////////////
    StableCryptoDollar private immutable i_SCDE;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% collateralization ratio
    uint256 private constant LIQUIDATION_BONUS = 10; // this means a 10% bonus
    uint256 private constant MIN_HELATH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADITIONAL_FED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    uint256 private constant LIQUIDATION_PRECISION = 100;

    mapping(address token => address s_priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256)) private s_collateralDeposited;
    mapping(address user => uint256 amountSCDEMinted) private s_SCDMinted;
    address[] private s_collateralTokens;

    //////////////////////
    // Events           //
    //////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralReedmed(
        address indexed redeemdFrom, address indexed redeemdTo, address indexed token, uint256 amount
    );

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
        if (s_priceFeeds[token] == address(0)) {
            revert SCDEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////
    // Funtions     //
    ///////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address SCDAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert SCDEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_SCDE = StableCryptoDollar(SCDAddress);
    }

    ////////////////////////
    // External Functions //
    ///////////////////////

    function depositCollateralAndMintSCD(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountScdToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintSCD(amountScdToMint);
    }

    function redeemCollateralForSCD(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountScdToBurn)
        external
        moreThanZero(amountCollateral)
    {
        _burnSCD(amountScdToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);

    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender,);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnSCD(uint256 amount) public moreThanZero(amount) {
        _burnScd(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

     function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HELATH_FACTOR) {
            revert SCDEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnScd(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert SCDEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }


    ///////////////////////
    // Public Functions //
    //////////////////////

    function mintSCD(
        uint256 amountSCDToMint 
    ) public moreThanZero(amountSCDToMint) nonReentrant {
        s_SCDMinted[msg.sender] += amountSCDToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_SCDE.mint(msg.sender, amountSCDToMint);

        if (!minted) {
            revert SCDEngine__MintFailed();
        }
    }

     function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool succes = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!succes) {
            revert SCDEngine__TransferFromFailed();
        }
    }

    ///////////////////////
    // Private Functions //
    //////////////////////

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralReedmed(tokenCollateralAddress, amountCollateral, from, to);
        bool succes = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!succes) {
            revert SCDEngine__TransferFromFailed();
        }
    }

    function _burnScd(uint256 amountScdToBurn, address onBehalfOf, address scdFrom) private {
        s_SCDMinted[onBehalfOf] -= amountScdToBurn;
        bool success = i_SCDE.transferFrom(scdFrom, address(this), amountScdToBurn);
        if (!success) {
            revert SCDEngine__TransferFromFailed();
        }
        i_SCDE.burn(amountScdToBurn);
    }

    ////////////////////////////////////////
    // Private & Internal View Functions //
    ///////////////////////////////////////

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        // if (totalDscMinted == 0) return type(uint256).max;
        // uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / 100;
        return (collateralAdjustedForThreshold * 1e18) / totalDscMinted;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalSCDMinted, uint256 collateralValueInUsd)
    {
        totalSCDMinted = s_SCDMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

     function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }


    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HELATH_FACTOR) {
            revert SCDEngine__BreakHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions /////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    
    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalSCDMinted, uint256 collateralValueInUsd)
    {
        (totalSCDMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

     function getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return _getUsdValue(token, amount);
    }

     function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

     function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADITIONAL_FED_PRECISION);
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADITIONAL_FED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}

