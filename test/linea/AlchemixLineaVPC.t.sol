// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";
import {Test, console2} from "../../lib/forge-std/src/Test.sol";
import {UD60x18, ud, intoUint256} from "../../lib/prb/src/UD60x18.sol";

import {IGauge, IRouter} from "../../src/interfaces/Lynex.sol";
import "../../src/linea/AlchemixLineaVPC.sol";

import {AlchemixLineaVPCDeployer} from "../../script/linea/AlchemixLineaVPCDeployer.s.sol";

contract AlchemixLineaVPCTest is Test {
    /* --- Alchemix --- */
    IAlchemixToken constant alcx = IAlchemixToken(0x303c4F39EA359155C698807168e9Dc3aA1dF2b95);

    /* --- Test Data --- */
    address constant koala = address(0xbadbabe);
    AlchemixLineaVPC vpc;

    function setUp() public {
        // Make sure we run the tests on an linea fork.
        uint256 BLOCK_NUMBER_LINEA = vm.envUint("BLOCK_NUMBER_LINEA");
        vm.createSelectFork("linea", BLOCK_NUMBER_LINEA);
        require(block.chainid == 59144, "Tests should be run on an linea fork");

        AlchemixLineaVPCDeployer deployer = new AlchemixLineaVPCDeployer();
        vpc = deployer.run();
    }

    /// forge-config: default.evm_version = "london"
    function testFork_getVotingPowerInTokens() external {
        uint256 votingPowerInTokens = 10e18;

        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        deal({token: address(alcx), to: koala, give: votingPowerInTokens, adjust: true});

        assertEq(vpc.getVotingPowerInTokens(koala), votingPowerInTokens, "naked ALCX voting power");
    }

    /// forge-config: default.evm_version = "london"
    function testFork_getVotingPowerInLynex() external {
        uint256 votingPowerInLynex = 10e18;

        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        deal({token: address(alcx), to: koala, give: votingPowerInLynex, adjust: true});

        // Mint some Usdc.
        IERC20 usdc = IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff);
        IRouter lynexRouter = IRouter(0x610D2f07b7EdC67565160F587F37636194C34E74);
        IPool lynexUsdcAlcxPool = IPool(0xaC73C5f3d110Bb051100cfD8Afa4aC4339f239E7);
        (uint256 alcxEquivalentAmountInUsdc,,) = lynexRouter.quoteAddLiquidity(
            address(usdc),
            address(alcx),
            lynexUsdcAlcxPool.stable(),
            type(uint128).max, // No upper limit.
            votingPowerInLynex
        );
        deal({token: address(usdc), to: koala, give: alcxEquivalentAmountInUsdc, adjust: true});

        // Add liquidity in the USDC/ALCX Lynex LP.
        vm.startPrank(koala, koala);
        usdc.approve(address(lynexRouter), type(uint256).max);
        alcx.approve(address(lynexRouter), type(uint256).max);
        (,, uint256 usdcAlcxLpBalance) = lynexRouter.addLiquidity(
            address(usdc),
            address(alcx),
            lynexUsdcAlcxPool.stable(),
            alcxEquivalentAmountInUsdc + 1, // Rounding error.
            votingPowerInLynex,
            alcxEquivalentAmountInUsdc,
            votingPowerInLynex,
            koala,
            block.timestamp
        );
        vm.stopPrank();

        // Test naked USDC/ALCX voting power in Lynex LP.
        assertEq(alcx.balanceOf(koala), 0, "Assert ALCX balance");
        assertApproxEqAbs(
            vpc.getVotingPower(koala), votingPowerInLynex, 1e11, "naked ALCX voting power in the USDC/ALCX Lynex pool"
        );

        uint256 usdcAlcxLpPosition = usdcAlcxLpBalance / 2; // Split the LP tokens into naked and staked (i.e. gauge) positions.

        // Stake in Lynex Gauge.
        IGauge lynexUsdcAlcxGauge = IGauge(0x0D47192a891Caba2f7cc349DD4392d2A1fA5082a);
        vm.startPrank(koala, koala);
        lynexUsdcAlcxPool.approve(address(lynexUsdcAlcxGauge), type(uint256).max);
        lynexUsdcAlcxGauge.deposit(usdcAlcxLpPosition);
        vm.stopPrank();

        // Test staked USDC/ALCX voting power in Lynex Gauge.
        assertEq(lynexUsdcAlcxGauge.balanceOf(koala), usdcAlcxLpPosition, "staked USDC/ALCX LP balance in Lynex");
        assertApproxEqAbs(
            vpc.getVotingPower(koala), votingPowerInLynex, 1e11, "naked + staked USDC/ALCX voting power in Lynex"
        );
    }
}
