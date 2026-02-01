// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";
import {Test, console2} from "../../lib/forge-std/src/Test.sol";
import {UD60x18, ud, intoUint256} from "../../lib/prb/src/UD60x18.sol";

import {IGauge, IRouter} from "../../src/interfaces/Ramses.sol";
import "../../src/arbitrum/AlchemixArbitrumVPC.sol";

import {AlchemixArbitrumVPCDeployer} from "../../script/arbitrum/AlchemixArbitrumVPCDeployer.s.sol";

contract AlchemixArbitrumVPCTest is Test {
    /* --- Alchemix --- */
    IAlchemixToken constant alcx = IAlchemixToken(0x27b58D226fe8f792730a795764945Cf146815AA7);

    /* --- Test Data --- */
    address constant koala = address(0xbadbabe);
    AlchemixArbitrumVPC vpc;

    function setUp() public {
        // Make sure we run the tests on an arbitrum fork.
        uint256 BLOCK_NUMBER_ARBITRUM = vm.envUint("BLOCK_NUMBER_ARBITRUM");
        vm.createSelectFork("arbitrum", BLOCK_NUMBER_ARBITRUM);
        require(block.chainid == 42161, "Tests should be run on an arbitrum fork");

        AlchemixArbitrumVPCDeployer deployer = new AlchemixArbitrumVPCDeployer();
        vpc = deployer.run();
    }

    function testFork_getVotingPowerInTokens() external {
        uint256 votingPowerInTokens = 10e18;

        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        deal({token: address(alcx), to: koala, give: votingPowerInTokens, adjust: true});

        assertEq(vpc.getVotingPowerInTokens(koala), votingPowerInTokens, "naked ALCX voting power");
    }

    function testFork_getVotingPowerInRamses() external {
        uint256 votingPowerInRamses = 10e18;

        // 1. Test the voting Power in the ALETH/ALCX LP.
        uint256 votingPowerInAlethAlcxPool = votingPowerInRamses / 2;
        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        deal({token: address(alcx), to: koala, give: votingPowerInAlethAlcxPool, adjust: true});

        // Mint some AlETH.
        IERC20 aleth = IERC20(0x17573150d67d820542EFb24210371545a4868B03);
        IRouter ramsesRouter = IRouter(0xAAA87963EFeB6f7E0a2711F397663105Acb1805e);
        IPool ramsesAlethAlcxPool = IPool(0x9C99764Ad164360cf85EdA42Fa2F4166B6CBA2A4);
        (uint256 alcxEquivalentAmountInAlETH,,) = ramsesRouter.quoteAddLiquidity(
            address(aleth),
            address(alcx),
            ramsesAlethAlcxPool.stable(),
            type(uint128).max, // No upper limit.
            votingPowerInAlethAlcxPool
        );
        deal({token: address(aleth), to: koala, give: alcxEquivalentAmountInAlETH, adjust: true});

        // Add liquidity in the ALETH/ALCX Ramses LP.
        vm.startPrank(koala, koala);
        alcx.approve(address(ramsesRouter), type(uint256).max);
        aleth.approve(address(ramsesRouter), type(uint256).max);
        (,, uint256 alethAlcxLpBalance) = ramsesRouter.addLiquidity(
            address(aleth),
            address(alcx),
            ramsesAlethAlcxPool.stable(),
            alcxEquivalentAmountInAlETH + 1, // Rounding error.
            votingPowerInAlethAlcxPool,
            alcxEquivalentAmountInAlETH,
            votingPowerInAlethAlcxPool,
            koala,
            block.timestamp
        );
        vm.stopPrank();

        // Test naked ALETH/ALCX voting power in Ramses LP.
        assertEq(alcx.balanceOf(koala), 0, "Assert ALCX balance");
        assertApproxEqAbs(
            vpc.getVotingPower(koala),
            votingPowerInAlethAlcxPool,
            1e5,
            "naked ALCX voting power in the ALETH/ALCX Ramses pool"
        );

        uint256 alethAlcxLpPosition = alethAlcxLpBalance / 2; // Split the LP tokens into naked and staked (i.e. gauge) positions.

        // Stake in Ramses Gauge.
        IGauge ramsesAlethAlcxGauge = IGauge(0xbAAD0fA7c22F81f407a416b9bF7E0148e87BFb59);
        vm.startPrank(koala, koala);
        ramsesAlethAlcxPool.approve(address(ramsesAlethAlcxGauge), type(uint256).max);
        ramsesAlethAlcxGauge.deposit(alethAlcxLpPosition, 0);
        vm.stopPrank();

        // Test staked ALETH/ALCX voting power in Ramses Gauge.
        assertEq(ramsesAlethAlcxGauge.balanceOf(koala), alethAlcxLpPosition, "staked ALETH/ALCX LP balance in Ramses");
        uint256 alethAlcxVP = vpc.getVotingPower(koala);
        assertApproxEqAbs(
            alethAlcxVP, votingPowerInAlethAlcxPool, 1e5, "naked + staked ALETH/ALCX voting power in Ramses"
        );

        // 2. Test the voting Power in the ALCX/WETH LP.
        uint256 votingPowerInAlcxWethPool = votingPowerInRamses / 2;
        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        deal({token: address(alcx), to: koala, give: votingPowerInAlcxWethPool, adjust: true});

        // Mint some WETH.
        IERC20 weth = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        IPool ramsesAlcxWethPool = IPool(0x531633a03f96DEb1C68EF02589c010A543aDbef2);
        (, uint256 alcxEquivalentAmountInWETH,) = ramsesRouter.quoteAddLiquidity(
            address(alcx),
            address(weth),
            ramsesAlethAlcxPool.stable(),
            votingPowerInAlcxWethPool,
            type(uint128).max // No upper limit.
        );
        deal({token: address(weth), to: koala, give: alcxEquivalentAmountInWETH, adjust: true});

        // Add liquidity in the ALCX/WETH Ramses LP.
        vm.startPrank(koala, koala);
        weth.approve(address(ramsesRouter), type(uint256).max);
        (,, uint256 alcxWethLpBalance) = ramsesRouter.addLiquidity(
            address(alcx),
            address(weth),
            ramsesAlcxWethPool.stable(),
            votingPowerInAlcxWethPool,
            alcxEquivalentAmountInWETH,
            votingPowerInAlcxWethPool,
            alcxEquivalentAmountInWETH,
            koala,
            block.timestamp
        );
        vm.stopPrank();

        // Test naked voting power in Ramses ALCX/WETH LP (+ existing position in Ramses).
        assertEq(alcx.balanceOf(koala), 0, "Assert ALCX balance");
        assertApproxEqAbs(
            vpc.getVotingPower(koala),
            alethAlcxVP + votingPowerInAlcxWethPool,
            1e3,
            "naked+staked ALETH/ALCX and naked ALCX/WETH voting power in Ramses"
        );

        uint256 alcxWethLpPosition = alcxWethLpBalance / 2; // Split the LP tokens into naked and staked (i.e. gauge) positions.

        // Stake in the ALCX/WETH Ramses Gauge.
        IGauge ramsesAlcxWethGauge = IGauge(0x41d6F80c44a208e0DFd44a68357B8452028a078d);
        vm.startPrank(koala, koala);
        ramsesAlcxWethPool.approve(address(ramsesAlcxWethGauge), type(uint256).max);
        ramsesAlcxWethGauge.deposit(alcxWethLpPosition, 0);
        vm.stopPrank();

        // Test staked ALCX/WETH voting power in Ramses Gauge (+ existing position in Ramses).
        assertEq(ramsesAlcxWethGauge.balanceOf(koala), alcxWethLpPosition, "staked ALCX ALCX/WETH LP balance in Ramses");
        assertApproxEqAbs(
            vpc.getVotingPower(koala),
            votingPowerInRamses,
            1e4,
            "naked+staked ALETH/ALCX and naked+staked ALCX/WETH voting power in Ramses"
        );
    }
}
