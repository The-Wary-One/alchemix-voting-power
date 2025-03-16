// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Test, console2} from "../../lib/forge-std/src/Test.sol";
import {UD60x18, ud, intoUint256} from "../../lib/prb/src/UD60x18.sol";

import {IBeefyVaultV7} from "../../src/interfaces/Beefy.sol";
import {IGauge, IRouter} from "../../src/interfaces/Velodrome.sol";
import "../../src/optimism/AlchemixOptimismVPC.sol";

import {AlchemixOptimismVPCDeployer} from "../../script/optimism/AlchemixOptimismVPCDeployer.s.sol";

contract AlchemixOptimismVPCTest is Test {
    /* --- Alchemix --- */
    IAlchemixToken constant alcx = IAlchemixToken(0xE974B9b31dBFf4369b94a1bAB5e228f35ed44125);

    /* --- Test Data --- */
    address constant koala = address(0xbadbabe);
    AlchemixOptimismVPC vpc;

    function setUp() public {
        // Make sure we run the tests on an optimism fork.
        uint256 BLOCK_NUMBER_OPTIMISM = vm.envUint("BLOCK_NUMBER_OPTIMISM");
        vm.createSelectFork("optimism", BLOCK_NUMBER_OPTIMISM);
        require(block.chainid == 10, "Tests should be run on an optimism fork");
        require(block.number == BLOCK_NUMBER_OPTIMISM);

        AlchemixOptimismVPCDeployer deployer = new AlchemixOptimismVPCDeployer();
        vpc = deployer.run();
    }

    function testFork_getVotingPowerInTokens() external {
        uint256 votingPowerInTokens = 10e18;

        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        deal({token: address(alcx), to: koala, give: votingPowerInTokens, adjust: true});

        // Test the voting power.
        assertEq(vpc.getVotingPower(koala), votingPowerInTokens, "naked ALCX voting power");
    }

    function testFork_getVotingPowerInVelodrome() external {
        uint256 votingPowerInVelodrome = 10e18;
        // Mint some ALCX to koala.
        vm.label(koala, "koala");
        deal({token: address(alcx), to: koala, give: votingPowerInVelodrome, adjust: true});

        IRouter veloRouter = IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

        // Mint some USDC.
        IERC20 usdc = IERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
        IPool veloUsdcAlcxPool = IPool(0x4B322314d6F7239F094f40d93e7d9C4A3081c625);
        (uint256 alcxEquivalentAmountInUSDC,,) = veloRouter.quoteAddLiquidity(
            address(usdc),
            address(alcx),
            veloUsdcAlcxPool.stable(),
            veloUsdcAlcxPool.factory(),
            type(uint128).max, // No upper limit.
            votingPowerInVelodrome
        );
        deal({token: address(usdc), to: koala, give: alcxEquivalentAmountInUSDC, adjust: true});

        // Add liquidity in the USDC/ALCX Velodrome LP.
        vm.startPrank(koala, koala);
        alcx.approve(address(veloRouter), type(uint256).max);
        usdc.approve(address(veloRouter), type(uint256).max);
        (,, uint256 lpBalance) = veloRouter.addLiquidity(
            address(usdc),
            address(alcx),
            veloUsdcAlcxPool.stable(),
            alcxEquivalentAmountInUSDC + 1, // Rounding error.
            votingPowerInVelodrome,
            alcxEquivalentAmountInUSDC,
            votingPowerInVelodrome,
            koala,
            block.timestamp
        );
        vm.stopPrank();

        // Test naked voting power in Velodrome LP.
        assertApproxEqAbs(
            vpc.getVotingPower(koala),
            votingPowerInVelodrome,
            0.0000001e18,
            "naked ALCX voting power in Velodrome"
        );

        uint256 lpPosition = lpBalance / 3; // Split the LP tokens into naked, gauge and beefy positions.

        // Stake in Velodrome Gauge.
        IGauge veloUsdcAlcxGauge = IGauge(0x8686cb49a95CD78F5fDF916c6F339F1256989967);
        vm.startPrank(koala, koala);
        veloUsdcAlcxPool.approve(address(veloUsdcAlcxGauge), type(uint256).max);
        veloUsdcAlcxGauge.deposit(lpPosition, koala);
        vm.stopPrank();

        // Test staked voting power in Velodrome Gauge.
        assertEq(veloUsdcAlcxGauge.balanceOf(koala), lpPosition, "staked ALCX LP balance in Velodrome");
        assertApproxEqAbs(
            vpc.getVotingPower(koala),
            votingPowerInVelodrome,
            0.0000001e18,
            "naked ALCX + staked voting power in Velodrome"
        );

        // Stake in Beefy.
        IBeefyVaultV7 beefyVault = IBeefyVaultV7(0x305aFC012538beBD12b162192e58d911D8Ab1B31);
        vm.startPrank(koala, koala);
        veloUsdcAlcxPool.approve(address(beefyVault), type(uint256).max);
        beefyVault.deposit(lpPosition);
        vm.stopPrank();

        // Test staked voting power in Beefy.
        assertApproxEqAbs(
            intoUint256(ud(beefyVault.balanceOf(koala)) * ud(beefyVault.getPricePerFullShare())),
            lpPosition,
            1, // Precision error.
            "staked ALCX LP balance in Beefy"
        );
        assertApproxEqAbs(
            vpc.getVotingPower(koala),
            votingPowerInVelodrome,
            0.001e18,
            "naked + staked ALCX voting power in Velodrome and Beefy"
        );
    }
}
