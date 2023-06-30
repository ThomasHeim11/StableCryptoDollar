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
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        SCDEngine mockDsce = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockDsc)
        );
        mockDsc.mint(user, amountCollateral);

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), amountCollateral);
        // Act / Assert
        vm.expectRevert(SCDEngine.SCDEngine__TransferFromFailed.selector);
        mockDsce.depositCollateral(address(mockDsc), amountCollateral);
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
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", user, amountCollateral);
        vm.startPrank(user);
        vm.expectRevert(SCDEngine.SCDEngine__TokenNotAllowed.selector);
        scde.depositCollateral(address(ranToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateral(weth, 0);
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
    // depositCollateralAndMintDsc Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
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

     modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(scde), amountCollateral);
        scde.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 userBalance = scd.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // mintDsc Tests //////////////////
    ///////////////////////////////////
    // This test needs it's own custom setup
    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintSCD mockDsc = new MockFailedMintSCD();
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        SCDEngine mockDsce = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockDsc)
        );
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockDsce), amountCollateral);

        vm.expectRevert(SCDEngine.SCDEngine__MintFailed.selector);
        mockDsce.depositCollateralAndMintSCD(weth, amountCollateral, amountToMint);
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
        // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
        // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
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

    function testCanMintDsc() public depositedCollateral {
        vm.prank(user);
        scde.mintSCD(amountToMint);

        uint256 userBalance = scd.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // burnDsc Tests //
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

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
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
        MockFailedTransfer mockDsc = new MockFailedTransfer();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        SCDEngine mockDsce = new SCDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockDsc)
        );
        mockDsc.mint(user, amountCollateral);

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), amountCollateral);
        // Act / Assert
        mockDsce.depositCollateral(address(mockDsc), amountCollateral);
        vm.expectRevert(SCDEngine.SCDEngine__TransferFromFailed.selector);
        mockDsce.redeemCollateral(address(mockDsc), amountCollateral);
        vm.stopPrank();
    }




}
