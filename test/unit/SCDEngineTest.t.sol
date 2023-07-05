// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeploySCD} from "../../script/DeploySCD.s.sol";
import {SCDEngine} from "../../src/SCDEngine.sol";
import {StableCryptoDollar} from "../../src/StableCryptoDollar.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockMoreDebtSCD} from "../mocks/MockMoreDebtSCD.sol";
import {MockFailedMintSCD} from "../mocks/MockFailedMintSCD.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {Test, console} from "forge-std/Test.sol";

contract SCDEngineTest is StdCheats, Test {
    SCDEngine public scde;
    StableCryptoDollar public scd;
    HelperConfig public helperConfig;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address public wbtc;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        DeploySCD deployer = new DeploySCD();
        (scd, scde, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    //////////////////////
    // Constructor Test //
    //////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoestMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(ethUsdPriceFeed);

        vm.expectRevert(SCDEngine.SCDEngine__TokenAddressAndPriceFeedAddressMustBeSameLength.selector);
        new SCDEngine(tokenAddresses, priceFeedAddresses, address(scd));
    }

    //////////////////////
    // Price Test Cases //
    //////////////////////

    function testGetTokenAmountFromUsd() public {
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = scde.getTokenAmountFromUsd(weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = scde.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    ////////////////////////////
    // DepositCollateral Test //
    ////////////////////////////

    function testRevertsIfTransferFromFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockScd = new MockFailedTransferFrom();
        tokenAddresses = [address(mockScd)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        SCDEngine mockScde = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockScd)
        );
        mockScd.mint(user, amountCollateral);

        vm.prank(owner);
        mockScd.transferOwnership(address(mockScde));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockScd)).approve(address(mockScde), amountCollateral);
        // Act / Assert
        vm.expectRevert(SCDEngine.SCDEngine__TransferFromFailed.selector);
        mockScde.depositCollateral(address(mockScd), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scd), amountCollateral);

        vm.expectRevert(SCDEngine.SCDEngine__NeedsMoreThanZero.selector);
        scde.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(SCDEngine.SCDEngine__TokenNotAllowed.selector, address(randToken)));
        scde.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = scd.balanceOf(user);
        assertEq(userBalance, 0);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalScdMinted, uint256 collateralValueInUsd) = scde.getAccountInformation(user);

        uint256 expectedTotalScdMinted = 0;
        uint256 expectedDepositAmount = scde.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalScdMinted, expectedTotalScdMinted);
        assertEq(expectedDepositAmount, amountCollateral);
    }

    ///////////////////////////////////////
    // DepositCollateralAndMintSCD Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedScdBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * scde.getAdditionalFeedPrecision())) / scde.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);

        uint256 expectedHealthFactor =
            scde.calculateHealthFactor(amountToMint, scde.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(SCDEngine.SCDEngine__BreakHealthFactor.selector, expectedHealthFactor));
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedScd() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedScd {
        uint256 userBalance = scd.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    //minScd Tests //////////////////
    ///////////////////////////////////
    // This test needs it's own custom setup
    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintSCD mockScd = new MockFailedMintSCD();
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        SCDEngine mockScde = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockScd)
        );
        mockScd.transferOwnership(address(mockScde));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockScde), amountCollateral);

        vm.expectRevert(SCDEngine.SCDEngine__MintFailed.selector);
        mockScde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.expectRevert(SCDEngine.SCDEngine__NeedsMoreThanZero.selector);
        scde.mintSCD(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * scde.getAdditionalFeedPrecision())) / scde.getPrecision();

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateral(weth, amountCollateral);

        uint256 expectedHealthFactor =
            scde.calculateHealthFactor(amountToMint, scde.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(SCDEngine.SCDEngine__BreakHealthFactor.selector, expectedHealthFactor));
        scde.mintSCD(amountToMint);
        vm.stopPrank();
    }

    function testCanMinedScd() public depositedCollateral {
        vm.prank(user);
        scde.mintSCD(amountToMint);

        uint256 userBalance = scd.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // burnSCD Tests //
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.expectRevert(SCDEngine.SCDEngine__NeedsMoreThanZero.selector);
        scde.burnSCD(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        scde.burnSCD(1);
    }

    function testCanBurnScd() public depositedCollateralAndMintedScd {
        vm.startPrank(user);
        scd.approve(address(scde), amountToMint);
        scde.burnSCD(amountToMint);
        vm.stopPrank();

        uint256 userBalance = scd.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////

    // this test needs it's own setup
    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockScd = new MockFailedTransfer();
        tokenAddresses = [address(mockScd)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        SCDEngine mockScde = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockScd)
        );
        mockScd.mint(user, amountCollateral);

        vm.prank(owner);
        mockScd.transferOwnership(address(mockScde));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockScd)).approve(address(mockScde), amountCollateral);
        // Act / Assert
        mockScde.depositCollateral(address(mockScd), amountCollateral);
        vm.expectRevert(SCDEngine.SCDEngine__TransferFromFailed.selector);
        mockScde.redeemCollateral(address(mockScd), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.expectRevert(SCDEngine.SCDEngine__NeedsMoreThanZero.selector);
        scde.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        scde.redeemCollateral(weth, amountCollateral);
        uint256 userBalance = ERC20Mock(weth).balanceOf(user);
        assertEq(userBalance, amountCollateral);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // redeemCollateralForScd Tests  //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedScd {
        vm.startPrank(user);
        scd.approve(address(scde), amountToMint);
        vm.expectRevert(SCDEngine.SCDEngine__NeedsMoreThanZero.selector);
        scde.redeemCollateralForSCD(weth, 0, amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        scd.approve(address(scde), amountToMint);
        scde.redeemCollateralForSCD(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        uint256 userBalance = scd.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    function testProperlyReportsHealthFactor() public depositedCollateralAndMintedScd {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = scde.getHealthFactor(user);
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedScd {
        int256 ethUsdUpdatedPrice = 18e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = scde.getHealthFactor(user);
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // This test needs it's own setup
    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtSCD mockScd = new MockMoreDebtSCD(ethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        SCDEngine mockScde = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockScd)
        );
        mockScd.transferOwnership(address(mockScde));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockScde), amountCollateral);
        mockScde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        // Arrange - Liquidator
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockScde), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockScde.depositCollateralAndMintSCD(weth, collateralToCover, amountToMint);
        mockScd.approve(address(mockScde), debtToCover);
        // Act
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        vm.expectRevert(SCDEngine.SCDEngine__HealthFactorNotImproved.selector);
        mockScde.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = scde.getHealthFactor(user);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(scde), collateralToCover);
        scde.depositCollateralAndMintSCD(weth, collateralToCover, amountToMint);
        scd.approve(address(scde), amountToMint);
        scde.liquidate(weth, user, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = scde.getTokenAmountFromUsd(weth, amountToMint)
            + (scde.getTokenAmountFromUsd(weth, amountToMint) / scde.getLiquidationBonus());
        uint256 hardCodedExpected = 6111111111111111110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = scde.getTokenAmountFromUsd(weth, amountToMint)
            + (scde.getTokenAmountFromUsd(weth, amountToMint) / scde.getLiquidationBonus());

        uint256 usdAmountLiquidated = scde.getUsdValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = scde.getUsdValue(weth, amountCollateral) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = scde.getAccountInformation(user);
        uint256 hardCodedExpectedValue = 70000000000000000020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorScdMinted,) = scde.getAccountInformation(liquidator);
        assertEq(liquidatorScdMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userScdMinted,) = scde.getAccountInformation(user);
        assertEq(userScdMinted, 0);
    }

    ///////////////////////////////////
    // View & Pure Function Tests   //
    //////////////////////////////////
    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = scde.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = scde.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = scde.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = scde.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = scde.getAccountInformation(user);
        uint256 expectedCollateralValue = scde.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralBalance = scde.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, amountCollateral);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralValue = scde.getAccountCollateralValue(user);
        uint256 expectedCollateralValue = scde.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetScd() public {
        address scdAddress = scde.getScd();
        assertEq(scdAddress, address(scd));
    }
}
