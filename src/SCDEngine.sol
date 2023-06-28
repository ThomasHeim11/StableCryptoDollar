// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error SCDEngine__BreakHealthFactor(uint256 healthFactor);
    error SCDEngine__MintFailed();

    //////////////////////
    // State Variables  //
    //////////////////////
    uint256 private constant ADITIONAL_FED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HELATH_FACTOR = 1e18;

    mapping(address token => address s_priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256)) private s_collateralDeposited;
    mapping(address user => uint256 amountSCDEMinted) private s_SCDMinted;
    address[] private s_collateralTokens;

    StableCryptoDollar private immutable i_SCDE;

    //////////////////////
    // Events           //
    //////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralReedmed(address indexed user, address indexed token, uint256 indexed amount);

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
            revert SCDEngine__NotAllowedToken();
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

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralReedmed(msg.sender, tokenCollateralAddress, amountCollateral);
        bool succes = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!succes) {
            revert SCDEngine__TransferFromFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralForSCD(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountScdToBurn)
        external
    {
        burnSCD(amountScdToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    function mintSCD(
        uint256 amountSCDToMint // Change this line
    ) public moreThanZero(amountSCDToMint) nonReentrant {
        s_SCDMinted[msg.sender] += amountSCDToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_SCDE.mint(msg.sender, amountSCDToMint);

        if (!minted) {
            revert SCDEngine__MintFailed();
        }
    }

    function burnSCD(uint256 amount) public moreThanZero(amount) {
        s_SCDMinted[msg.sender] -= amount;
        bool success = i_SCDE.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert SCDEngine__TransferFromFailed();
        }
        i_SCDE.burn(amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate(address collateral, address user, uint256 debtToCover) 
        external 
        moreThanZero(debtToCover)
        nonReentrant
         {
            uint256 startingUserHealthFactor = _healthFactor(user);
            if(starting)

        }
    

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
        (uint256 totalSCDMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalSCDMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HELATH_FACTOR) {
            revert SCDEngine__BreakHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////
    // Public & External View Functions //
    ///////////////////////////////////////
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (((uint256(price) * ADITIONAL_FED_PRECISION) * amount) / PRECISION);
    }
}
