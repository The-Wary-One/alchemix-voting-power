// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "../lib/forge-std/src/Test.sol";

import "../src/AlchemixVotes.sol";
import {IConvexBooster} from "../src/interfaces/Curve.sol";

contract AlchemixVotesTest is Test {
    /* --- Alchemix --- */
    IAlchemixToken constant ALCX = IAlchemixToken(0xdBdb4d16EdA451D0503b854CF79D55697F90c8DF);
    IERC20 constant gALCX = IERC20(0x93Dede06AE3B5590aF1d4c111BC54C3f717E4b35);
    IStakingPool constant alchemixStakingPools = IStakingPool(0xAB8e74017a8Cc7c15FFcCd726603790d26d7DeCa);
    /* --- Tokemak --- */
    IERC20 constant tALCX = IERC20(0xD3B5D9a561c293Fb42b446FE7e237DaA9BF9AA84);
    /* --- Sushiswap --- */
    IUniswapV2Pair constant sushiswapALCXLP = IUniswapV2Pair(0xC3f279090a47e80990Fe3a9c30d24Cb117EF91a8);
    IMasterChef constant masterChef = IMasterChef(0xEF0881eC094552b2e128Cf945EF17a6752B4Ec5d);
    /* --- Balancer/Aura --- */
    IERC20 constant balancerALCXLP = IERC20(0xf16aEe6a71aF1A9Bc8F56975A4c2705ca7A782Bc);
    IERC20 constant balancerALCXLPStaking = IERC20(0x183D73dA7adC5011EC3C46e33BB50271e59EC976);
    IVault constant balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 constant balancerALCXPoolId = bytes32(0xf16aee6a71af1a9bc8f56975a4c2705ca7a782bc0002000000000000000004bb);
    IERC20 constant auraBalancerALCXLPVault = IERC20(0x8B227E3D50117E80a02cd0c67Cd6F89A8b7B46d7);
    /* --- Curve/Convex --- */
    IERC20 constant curveALCXFraxBPLP = IERC20(0xf985005a3793DbA4cCe241B3C19ddcd3Fe069ff4);
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
    AlchemixVotes votes;

    /// @dev Setup the environment for the tests.
    function setUp() public virtual {
        // Make sure we run the tests on a mainnet fork.
        Chain memory mainnet = getChain("mainnet");
        uint256 BLOCK_NUMBER_MAINNET = vm.envUint("BLOCK_NUMBER_MAINNET");
        vm.createSelectFork(mainnet.rpcUrl, BLOCK_NUMBER_MAINNET);
        require(block.chainid == 1, "Tests should be run on a mainnet fork");

        votes = new AlchemixVotes();

        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        _mintALCX(koala, voteAmount);
    }

    function testFork_ALCXVotes() external {
        assertEq(votes.ALCXVotes(koala), voteAmount, "naked ALCX");
        // Stake some ALCX.
        vm.startPrank(koala, koala);
        ALCX.approve(address(alchemixStakingPools), type(uint256).max);
        alchemixStakingPools.deposit(1, 5e18);
        vm.stopPrank();
        assertEq(alchemixStakingPools.getStakeTotalDeposited(koala, 1), 5e18, "staked ALCX in Staking Pool");
        assertEq(votes.ALCXVotes(koala), voteAmount, "naked + staked ALCX");
    }

    function testFork_BalancerALCXWETHLPVotes() external {}

    function testFork_CurveALCXFraxBPLPVotes() external {
        // Deposit in the Curve ALCX-FraxBP.
        uint256 votesInCurve = 10e18;
        vm.startPrank(koala, koala);
        ALCX.approve(address(curveALCXFraxBPPool), type(uint256).max);
        uint256 lpBalance = curveALCXFraxBPPool.add_liquidity([votesInCurve, 0], 0, false, koala);
        vm.stopPrank();
        uint256 calculatedVotesInCurve = votes.CurveALCXFraxBPLPVotes(koala);
        assertApproxEqAbs(calculatedVotesInCurve, votesInCurve, 0.05e18, "naked ALCX in Curve");
        uint256 stakedVotesAmount = lpBalance / 4;
        // Stake in Curve.
        vm.startPrank(koala, koala);
        curveALCXFraxBPLP.approve(address(curveALCXFraxBPGauge), type(uint256).max);
        curveALCXFraxBPGauge.deposit(stakedVotesAmount, koala, false);
        vm.stopPrank();
        assertEq(curveALCXFraxBPGauge.balanceOf(koala), stakedVotesAmount, "staked ALCX in Curve");
        assertEq(votes.CurveALCXFraxBPLPVotes(koala), calculatedVotesInCurve, "naked + staked ALCX in Curve");
        // Stake in Convex.
        vm.startPrank(koala, koala);
        curveALCXFraxBPLP.approve(address(convexBooster), type(uint256).max);
        convexBooster.deposit(120, stakedVotesAmount, true);
        vm.stopPrank();
        assertEq(convexALCXFraxBPRewardPool.balanceOf(koala), stakedVotesAmount, "staked ALCX in Convex");
        assertEq(
            votes.CurveALCXFraxBPLPVotes(koala),
            calculatedVotesInCurve,
            "naked + staked ALCX in Curve + staked in Convex"
        );
        // Stake in Frax.
        vm.startPrank(koala, koala);
        curveALCXFraxBPLP.approve(address(fraxStakingPool), type(uint256).max);
        fraxStakingPool.deposit(stakedVotesAmount, koala);
        vm.stopPrank();
        assertEq(fraxStakingPool.balanceOf(koala), stakedVotesAmount, "staked ALCX in Frax");
        assertEq(
            votes.CurveALCXFraxBPLPVotes(koala),
            calculatedVotesInCurve,
            "naked + staked ALCX in Curve + staked in Convex + staked in Frax"
        );
    }

    function _mintALCX(address to, uint256 amount) internal {
        deal({token: address(ALCX), to: to, give: amount, adjust: true});
        // address admin = ALCX.getRoleMember(ALCX.MINTER_ROLE(), 0);
        // vm.prank(admin, admin);
        // ALCX.mint(to, amount);
    }
}
