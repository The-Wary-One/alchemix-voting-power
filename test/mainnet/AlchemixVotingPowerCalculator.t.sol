// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Test, console2} from "../../lib/forge-std/src/Test.sol";

import "../../src/mainnet/AlchemixVotingPowerCalculator.sol";
import {IRouter as IBalancerRouter, IPermit2, IWETH} from "../../src/interfaces/Balancer.sol";
import {IConvexBooster, IFraxBooster, IFraxStakingProxy} from "../../src/interfaces/Curve.sol";
import {IUniswapV2Router02} from "../../src/interfaces/Sushiswap.sol";

import {AlchemixVotingPowerCalculatorDeployer} from "../../script/mainnet/AlchemixVotingPowerCalculatorDeployer.s.sol";

contract AlchemixVotingPowerCalculatorTest is Test {
    /* --- Alchemix --- */
    IAlchemixToken constant ALCX = IAlchemixToken(0xdBdb4d16EdA451D0503b854CF79D55697F90c8DF);
    IgALCX constant gALCX = IgALCX(0x93Dede06AE3B5590aF1d4c111BC54C3f717E4b35);
    IStakingPool constant alchemixStakingPools = IStakingPool(0xAB8e74017a8Cc7c15FFcCd726603790d26d7DeCa);
    /* --- Tokemak --- */
    ITokemakPool constant tALCX = ITokemakPool(0xD3B5D9a561c293Fb42b446FE7e237DaA9BF9AA84);
    /* --- Sushiswap --- */
    IUniswapV2Pair constant sushiswapALCXLP = IUniswapV2Pair(0xC3f279090a47e80990Fe3a9c30d24Cb117EF91a8);
    IMasterChef constant masterChef = IMasterChef(0xEF0881eC094552b2e128Cf945EF17a6752B4Ec5d);
    IUniswapV2Router02 constant sushiswapRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    /* --- Balancer/Aura --- */
    IWETH constant weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IPermit2 constant permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IERC20 constant balancerALCXLP = IERC20(0x1535D7CA00323Aa32BD62AEDdf7ca651e4b95966);
    ICurveGauge constant balancerALCXLPStaking = ICurveGauge(0x2F534f93928B99A4759a5C6a75a61b34132a06ff);
    IVault constant balancerVault = IVault(0xbA1333333333a1BA1108E8412f11850A5C319bA9);
    IBalancerRouter constant balancerRouter = IBalancerRouter(0xAE563E3f8219521950555F5962419C8919758Ea2);
    IConvexRewardPool constant auraBalancerALCXLPVault = IConvexRewardPool(0x39b2b74b817f0A10a5fA67a3EDCf5705A750c43C);
    IConvexBooster constant auraBooster = IConvexBooster(0xA57b8d98dAE62B26Ec3bcC4a365338157060B234);
    /* --- Curve/Convex --- */
    IERC20 constant curveALCXFraxBPLP = IERC20(0xf985005a3793DbA4cCe241B3C19ddcd3Fe069ff4);
    IERC20 constant FraxBP = IERC20(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    ICurvePool constant curveALCXFraxBPPool = ICurvePool(0x4149d1038575CE235E03E03B39487a80FD709D31);
    ICurveGauge constant curveALCXFraxBPGauge = ICurveGauge(0xD5bE6A05B45aEd524730B6d1CC05F59b021f6c87);
    IConvexRewardPool constant convexALCXFraxBPRewardPool =
        IConvexRewardPool(0xC10fD95fd3B56535668426B2c8681AD1E15Be608);
    IConvexBooster constant convexBooster = IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address constant convexVoter = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;
    IConvexStakingWrapperFrax constant fraxStakingPool =
        IConvexStakingWrapperFrax(0xAF1b82809296E52A42B3452c52e301369Ce20554);
    IFraxBooster constant fraxBooster = IFraxBooster(0xD8Bd5Cdd145ed2197CB16ddB172DF954e3F28659);
    IFraxPoolRegistry constant fraxPoolRegistry = IFraxPoolRegistry(0x41a5881c17185383e19Df6FA4EC158a6F4851A69);
    /* --- Test Data --- */
    address constant koala = address(0xbadbabe);
    uint256 constant voteAmount = 100e18;
    AlchemixVotingPowerCalculator votingPowerCalculator;

    /// @dev Setup the environment for the tests.
    function setUp() public {
        // Make sure we run the tests on a mainnet fork.
        uint256 BLOCK_NUMBER_MAINNET = vm.envUint("BLOCK_NUMBER_MAINNET");
        vm.createSelectFork("mainnet", BLOCK_NUMBER_MAINNET);
        require(block.chainid == 1, "Tests should be run on a mainnet fork");
        require(block.number == BLOCK_NUMBER_MAINNET, "Tests should be run on a mainnet fork");

        AlchemixVotingPowerCalculatorDeployer deployer = new AlchemixVotingPowerCalculatorDeployer();
        votingPowerCalculator = deployer.run();

        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        vm.deal(koala, 10 ether);
        deal({token: address(ALCX), to: koala, give: voteAmount, adjust: true});
    }

    function testFork_ALCXVotingPower() external {
        assertEq(votingPowerCalculator.ALCXVotingPower(koala), voteAmount, "naked ALCX voting power");
        // Stake some ALCX.
        vm.startPrank(koala, koala);
        ALCX.approve(address(alchemixStakingPools), type(uint256).max);
        alchemixStakingPools.deposit(1, 5e18);
        vm.stopPrank();
        assertEq(alchemixStakingPools.getStakeTotalDeposited(koala, 1), 5e18, "staked ALCX balance in Staking Pool");
        assertEq(votingPowerCalculator.ALCXVotingPower(koala), voteAmount, "naked + staked ALCX voting power");
    }

    function testFork_gALCXVotingPower() external {
        uint256 votingPowerIngALCX = 10e18;
        // Stake in gALCX.
        vm.startPrank(koala, koala);
        ALCX.approve(address(gALCX), type(uint256).max);
        gALCX.stake(votingPowerIngALCX);
        vm.stopPrank();
        assertTrue(gALCX.balanceOf(koala) > 0, "naked gALCX balance");
        assertEq(votingPowerCalculator.gALCXVotingPower(koala), votingPowerIngALCX, "naked gALCX voting power");
    }

    function testFork_tALCXVotingPower() external {
        uint256 votingPowerInTokemak = 10e18;
        // Deposit in Tokemak.
        vm.startPrank(koala, koala);
        ALCX.approve(address(tALCX), type(uint256).max);
        tALCX.deposit(votingPowerInTokemak);
        vm.stopPrank();
        assertEq(tALCX.balanceOf(koala), votingPowerInTokemak, "naked tALCX balance");
        assertEq(votingPowerCalculator.tALCXVotingPower(koala), votingPowerInTokemak, "naked tALCX voting power");
        // Stake some tALCX.
        vm.startPrank(koala, koala);
        tALCX.approve(address(alchemixStakingPools), type(uint256).max);
        alchemixStakingPools.deposit(8, 5e18);
        vm.stopPrank();
        assertEq(alchemixStakingPools.getStakeTotalDeposited(koala, 8), 5e18, "staked tALCX balance in Staking Pool");
        assertEq(
            votingPowerCalculator.tALCXVotingPower(koala), votingPowerInTokemak, "naked + staked tALCX voting power"
        );
    }

    function testFork_SushiswapALCXWETHLPVotingPower() external {
        uint256 votingPowerInSushiswap = 10e18;
        // Deposit in the Sushiswap ALCX-WETH LP.
        vm.startPrank(koala, koala);
        ALCX.approve(address(sushiswapRouter), type(uint256).max);
        sushiswapRouter.addLiquidityETH{value: 1 ether}(
            address(ALCX), votingPowerInSushiswap, votingPowerInSushiswap, 0, koala, block.timestamp + 1
        );
        vm.stopPrank();
        uint256 calculatedVotingPowerInSushiswap = votingPowerCalculator.SushiswapALCXWETHLPVotingPower(koala);
        assertApproxEqAbs(
            calculatedVotingPowerInSushiswap, votingPowerInSushiswap, 200, "naked ALCX voting power in Sushiswap"
        );
        // Stake in Sushiswap.
        uint256 stakedVotingPowerAmount = sushiswapALCXLP.balanceOf(koala) / 2;
        vm.startPrank(koala, koala);
        sushiswapALCXLP.approve(address(masterChef), type(uint256).max);
        masterChef.deposit(0, stakedVotingPowerAmount, koala);
        vm.stopPrank();
        (uint256 stakedSushiLPBalance,) = masterChef.userInfo(0, koala);
        assertEq(stakedSushiLPBalance, stakedVotingPowerAmount, "staked ALCX balance in Sushiswap");
        assertEq(
            votingPowerCalculator.SushiswapALCXWETHLPVotingPower(koala),
            calculatedVotingPowerInSushiswap,
            "naked + staked ALCX voting power in Sushiswap"
        );
    }

    function testFork_BalancerALCXWETHLPVotingPower() external {
        // Deposit in the Balancer 20%WETH-80%ALCX Pool.
        // If we want to LP with 8 ALCX, we need 2 ALCX worth of ETH too.
        uint256 votingPowerInBalancer = 8e18;
        // tokens[] is WETH and tokens[1] is ALCX.
        uint256[] memory liveBalances = balancerVault.getCurrentLiveBalances(address(balancerALCXLP));
        uint256 wethBalanceInLP = liveBalances[0];
        uint256 alcxBalanceInLP = liveBalances[1];
        uint256 neededAmountOfWeth = wethBalanceInLP * votingPowerInBalancer / alcxBalanceInLP;

        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = neededAmountOfWeth;
        amountsIn[1] = votingPowerInBalancer;

        vm.startPrank(koala, koala);
        weth.deposit{value: 5e18}(5e18); // Setup the weth balance.
        weth.approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(balancerRouter), type(uint160).max, type(uint48).max);
        ALCX.approve(address(permit2), type(uint256).max);
        permit2.approve(address(ALCX), address(balancerRouter), type(uint160).max, type(uint48).max);
        balancerRouter.addLiquidityUnbalanced(address(balancerALCXLP), amountsIn, 1, false, bytes(""));
        vm.stopPrank();

        uint256 lpBalance = balancerALCXLP.balanceOf(koala);
        uint256 calculatedVotingPowerInBalancer = votingPowerCalculator.BalancerALCXWETHLPVotingPower(koala);

        assertApproxEqAbs(
            votingPowerCalculator.BalancerALCXWETHLPVotingPower(koala),
            votingPowerInBalancer,
            0.05e18,
            "naked ALCX voting power in Balancer"
        );

        // Stake in Balancer.
        uint256 stakedVotingPowerAmount = lpBalance / 4;
        vm.startPrank(koala, koala);
        balancerALCXLP.approve(address(balancerALCXLPStaking), type(uint256).max);
        balancerALCXLPStaking.deposit(stakedVotingPowerAmount, koala, false);
        vm.stopPrank();
        assertEq(balancerALCXLPStaking.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Balancer");
        assertEq(
            votingPowerCalculator.BalancerALCXWETHLPVotingPower(koala),
            calculatedVotingPowerInBalancer,
            "naked + staked ALCX voting power in Balancer"
        );

        // Stake in Aura.
        vm.startPrank(koala, koala);
        balancerALCXLP.approve(address(auraBooster), type(uint256).max);
        auraBooster.deposit(277, stakedVotingPowerAmount, true); // 277 is the aura pool id
        vm.stopPrank();

        assertEq(auraBalancerALCXLPVault.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Aura");
        assertEq(
            votingPowerCalculator.BalancerALCXWETHLPVotingPower(koala),
            calculatedVotingPowerInBalancer,
            "naked + staked ALCX voting power in Balancer and Aura"
        );
    }

    function testFork_CurveALCXFraxBPLPVotingPower() external {
        uint256 votingPowerInCurve = 10e18;
        // Mint some FraxBP.
        uint256 correspondingFraxBPAmount = (votingPowerInCurve * 1e18) / curveALCXFraxBPPool.price_oracle();
        deal({token: address(FraxBP), to: koala, give: correspondingFraxBPAmount, adjust: true});
        // Deposit in the Curve ALCX-FraxBP.
        vm.startPrank(koala, koala);
        ALCX.approve(address(curveALCXFraxBPPool), type(uint256).max);
        FraxBP.approve(address(curveALCXFraxBPPool), type(uint256).max);
        uint256 lpBalance =
            curveALCXFraxBPPool.add_liquidity([votingPowerInCurve, correspondingFraxBPAmount], 1000, false, koala);
        vm.stopPrank();
        uint256 calculatedVotingPowerInCurve = votingPowerCalculator.CurveALCXFraxBPLPVotingPower(koala);
        assertApproxEqAbs(calculatedVotingPowerInCurve, votingPowerInCurve, 0.15e18, "naked ALCX voting power in Curve");
        // Stake in Curve.
        uint256 stakedVotingPowerAmount = lpBalance / 4;
        vm.startPrank(koala, koala);
        curveALCXFraxBPLP.approve(address(curveALCXFraxBPGauge), type(uint256).max);
        curveALCXFraxBPGauge.deposit(stakedVotingPowerAmount, koala, false);
        vm.stopPrank();
        assertEq(curveALCXFraxBPGauge.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Curve");
        assertEq(
            votingPowerCalculator.CurveALCXFraxBPLPVotingPower(koala),
            calculatedVotingPowerInCurve,
            "naked + staked ALCX voting power in Curve"
        );
        // Stake in Convex.
        vm.startPrank(koala, koala);
        curveALCXFraxBPLP.approve(address(convexBooster), type(uint256).max);
        convexBooster.deposit(120, stakedVotingPowerAmount, true);
        vm.stopPrank();
        assertEq(convexALCXFraxBPRewardPool.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Convex");
        assertEq(
            votingPowerCalculator.CurveALCXFraxBPLPVotingPower(koala),
            calculatedVotingPowerInCurve,
            "naked + staked ALCX voting power in Curve and Convex"
        );
        // Stake in Frax.
        vm.startPrank(koala, koala);
        fraxBooster.createVault(23);
        IFraxStakingProxy fraxVault = IFraxStakingProxy(fraxPoolRegistry.vaultMap(23, koala));
        curveALCXFraxBPLP.approve(address(fraxVault), type(uint256).max);
        fraxVault.stakeLockedCurveLp(stakedVotingPowerAmount, 52 weeks);
        vm.stopPrank();
        assertEq(
            fraxStakingPool.totalBalanceOf(address(fraxVault)), stakedVotingPowerAmount, "staked ALCX balance in Frax"
        );
        assertEq(
            votingPowerCalculator.CurveALCXFraxBPLPVotingPower(koala),
            calculatedVotingPowerInCurve,
            "naked + staked ALCX voting power in Curve, Convex and Frax"
        );
    }
}
