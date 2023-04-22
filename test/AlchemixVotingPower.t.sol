// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "../lib/forge-std/src/Test.sol";

import "../src/AlchemixVotingPower.sol";
import {IConvexBooster} from "../src/interfaces/Curve.sol";
import {IUniswapV2Router02} from "../src/interfaces/Sushiswap.sol";

contract AlchemixVotingPowerTest is Test {
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
    IERC20 constant balancerALCXLP = IERC20(0xf16aEe6a71aF1A9Bc8F56975A4c2705ca7A782Bc);
    ICurveGauge constant balancerALCXLPStaking = ICurveGauge(0x183D73dA7adC5011EC3C46e33BB50271e59EC976);
    IVault constant balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 constant balancerALCXPoolId = bytes32(0xf16aee6a71af1a9bc8f56975a4c2705ca7a782bc0002000000000000000004bb);
    IConvexRewardPool constant auraBalancerALCXLPVault = IConvexRewardPool(0x8B227E3D50117E80a02cd0c67Cd6F89A8b7B46d7);
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
    /* --- Test Data --- */
    address constant koala = address(0xbadbabe);
    uint256 constant voteAmount = 100e18;
    AlchemixVotingPower votingPower;

    /// @dev Setup the environment for the tests.
    function setUp() public virtual {
        // Make sure we run the tests on a mainnet fork.
        Chain memory mainnet = getChain("mainnet");
        uint256 BLOCK_NUMBER_MAINNET = vm.envUint("BLOCK_NUMBER_MAINNET");
        vm.createSelectFork(mainnet.rpcUrl, BLOCK_NUMBER_MAINNET);
        require(block.chainid == 1, "Tests should be run on a mainnet fork");

        votingPower = new AlchemixVotingPower();

        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        vm.deal(koala, 10 ether);
        deal({token: address(ALCX), to: koala, give: voteAmount, adjust: true});
    }

    function testFork_ALCXVotingPower() external {
        assertEq(votingPower.ALCXVotingPower(koala), voteAmount, "naked ALCX voting power");
        // Stake some ALCX.
        vm.startPrank(koala, koala);
        ALCX.approve(address(alchemixStakingPools), type(uint256).max);
        alchemixStakingPools.deposit(1, 5e18);
        vm.stopPrank();
        assertEq(alchemixStakingPools.getStakeTotalDeposited(koala, 1), 5e18, "staked ALCX balance in Staking Pool");
        assertEq(votingPower.ALCXVotingPower(koala), voteAmount, "naked + staked ALCX voting power");
    }

    function testFork_gALCXVotingPower() external {
        uint256 votingPowerIngALCX = 10e18;
        // Stake in gALCX.
        vm.startPrank(koala, koala);
        ALCX.approve(address(gALCX), type(uint256).max);
        gALCX.stake(votingPowerIngALCX);
        vm.stopPrank();
        assertTrue(gALCX.balanceOf(koala) > 0, "naked gALCX balance");
        assertEq(votingPower.gALCXVotingPower(koala), votingPowerIngALCX, "naked gALCX voting power");
    }

    function testFork_tALCXVotingPower() external {
        uint256 votingPowerInTokemak = 10e18;
        // Deposit in Tokemak.
        vm.startPrank(koala, koala);
        ALCX.approve(address(tALCX), type(uint256).max);
        tALCX.deposit(votingPowerInTokemak);
        vm.stopPrank();
        assertEq(tALCX.balanceOf(koala), votingPowerInTokemak, "naked tALCX balance");
        assertEq(votingPower.tALCXVotingPower(koala), votingPowerInTokemak, "naked tALCX voting power");
        // Stake some tALCX.
        vm.startPrank(koala, koala);
        tALCX.approve(address(alchemixStakingPools), type(uint256).max);
        alchemixStakingPools.deposit(8, 5e18);
        vm.stopPrank();
        assertEq(alchemixStakingPools.getStakeTotalDeposited(koala, 8), 5e18, "staked tALCX balance in Staking Pool");
        assertEq(votingPower.tALCXVotingPower(koala), votingPowerInTokemak, "naked + staked tALCX voting power");
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
        uint256 calculatedVotingPowerInSushiswap = votingPower.SushiswapALCXWETHLPVotingPower(koala);
        assertApproxEqAbs(
            calculatedVotingPowerInSushiswap, votingPowerInSushiswap, 100, "naked ALCX voting power in Sushiswap"
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
            votingPower.SushiswapALCXWETHLPVotingPower(koala),
            calculatedVotingPowerInSushiswap,
            "naked + staked ALCX voting power in Sushiswap"
        );
    }

    function testFork_BalancerALCXWETHLPVotingPower() external {
        // Deposit in the Balancer 20WETH-80ALCX Pool.
        uint256 votingPowerInBalancer = 10e18;
        vm.startPrank(koala, koala);
        ALCX.approve(address(balancerVault), type(uint256).max);
        (address[] memory tokens,,) = balancerVault.getPoolTokens(balancerALCXPoolId);
        tokens[0] = address(0);
        uint256[] memory maxIn = new uint256[](2);
        // Hardcoded 10*0.2/0.8=2.5 ALCX amount in ETH at writing.
        // Could be calculated using https://token-engineering-balancer.gitbook.io/balancer-simulations/additional-code-and-instructions/balancer-the-python-edition/balancer_math.py#calc_out_given_in.
        uint256 hardcodedEthAmount = 0.024e18;
        maxIn[0] = hardcodedEthAmount;
        maxIn[1] = votingPowerInBalancer;
        IVault.JoinPoolRequest memory pr = IVault.JoinPoolRequest(
            tokens, maxIn, abi.encode(IVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxIn, 0), false
        );
        balancerVault.joinPool{value: hardcodedEthAmount}(balancerALCXPoolId, koala, koala, pr);
        vm.stopPrank();
        uint256 lpBalance = balancerALCXLP.balanceOf(koala);
        uint256 calculatedVotingPowerInBalancer = votingPower.BalancerALCXWETHLPVotingPower(koala);
        assertApproxEqAbs(
            votingPower.BalancerALCXWETHLPVotingPower(koala),
            votingPowerInBalancer,
            0.05e18,
            "naked ALCX voting power in Balancer"
        );
        // Stake in Balancer.
        uint256 stakedVotingPowerAmount = lpBalance / 3;
        vm.startPrank(koala, koala);
        balancerALCXLP.approve(address(balancerALCXLPStaking), type(uint256).max);
        balancerALCXLPStaking.deposit(stakedVotingPowerAmount, koala, false);
        vm.stopPrank();
        assertEq(balancerALCXLPStaking.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Balancer");
        assertEq(
            votingPower.BalancerALCXWETHLPVotingPower(koala),
            calculatedVotingPowerInBalancer,
            "naked + staked ALCX voting power in Balancer"
        );
        // Stake in Aura.
        vm.startPrank(koala, koala);
        balancerALCXLP.approve(address(auraBooster), type(uint256).max);
        auraBooster.deposit(74, stakedVotingPowerAmount, true);
        vm.stopPrank();
        assertEq(auraBalancerALCXLPVault.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Convex");
        assertEq(
            votingPower.BalancerALCXWETHLPVotingPower(koala),
            calculatedVotingPowerInBalancer,
            "naked + staked ALCX voting power in Balancer and Aura"
        );
    }

    function testFork_CurveALCXFraxBPLPVotingPower() external {
        uint256 votingPowerInCurve = 10e18;
        // Mint some FraxBP.
        uint256 correspondingFraxBPAmount = votingPowerInCurve * 1e18 / curveALCXFraxBPPool.price_oracle();
        deal({token: address(FraxBP), to: koala, give: correspondingFraxBPAmount, adjust: true});
        // Deposit in the Curve ALCX-FraxBP.
        vm.startPrank(koala, koala);
        ALCX.approve(address(curveALCXFraxBPPool), type(uint256).max);
        FraxBP.approve(address(curveALCXFraxBPPool), type(uint256).max);
        uint256 lpBalance =
            curveALCXFraxBPPool.add_liquidity([votingPowerInCurve, correspondingFraxBPAmount], 0, false, koala);
        vm.stopPrank();
        uint256 calculatedVotingPowerInCurve = votingPower.CurveALCXFraxBPLPVotingPower(koala);
        assertApproxEqAbs(calculatedVotingPowerInCurve, votingPowerInCurve, 0.15e18, "naked ALCX voting power in Curve");
        // Stake in Curve.
        uint256 stakedVotingPowerAmount = lpBalance / 4;
        vm.startPrank(koala, koala);
        curveALCXFraxBPLP.approve(address(curveALCXFraxBPGauge), type(uint256).max);
        curveALCXFraxBPGauge.deposit(stakedVotingPowerAmount, koala, false);
        vm.stopPrank();
        assertEq(curveALCXFraxBPGauge.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Curve");
        assertEq(
            votingPower.CurveALCXFraxBPLPVotingPower(koala),
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
            votingPower.CurveALCXFraxBPLPVotingPower(koala),
            calculatedVotingPowerInCurve,
            "naked + staked ALCX voting power in Curve and Convex"
        );
        // Stake in Frax.
        vm.startPrank(koala, koala);
        curveALCXFraxBPLP.approve(address(fraxStakingPool), type(uint256).max);
        fraxStakingPool.deposit(stakedVotingPowerAmount, koala);
        vm.stopPrank();
        assertEq(fraxStakingPool.balanceOf(koala), stakedVotingPowerAmount, "staked ALCX balance in Frax");
        assertEq(
            votingPower.CurveALCXFraxBPLPVotingPower(koala),
            calculatedVotingPowerInCurve,
            "naked + staked ALCX voting power in Curve, Convex and Frax"
        );
    }
}
