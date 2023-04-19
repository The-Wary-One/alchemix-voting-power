//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";

import {IAlchemixToken, IStakingPool} from "./interfaces/Alchemix.sol";
import {IVault} from "./interfaces/Balancer.sol";
import {IConvexRewardPool, ICurveGauge, ICurvePool} from "./interfaces/Curve.sol";
import {IMasterChef, IUniswapV2Pair} from "./interfaces/Sushiswap.sol";

contract AlchemixVotes {
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
    address constant convexVoter = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;

    function getVotes(address account) external view returns (uint256 votes) {
        // 1. Get the naked and staked `ALCX` balance.
        votes = ALCXVotes(account);
        // 2. Get the `gALCX` balance.
        votes += gALCXVotes(account);
        // 3. Get the `ALCX` balance in tokemak, `tALCX`.
        votes += tALCXVotes(account);
        // 4. Get the naked and staked Sushiswap ALCX/WETH LP Position.
        votes += SushiswapALCXWETHLPVotes(account);
        // 5. Get the naked and staked (in Balancer and Aura) Balancer ALCX/WETH LP Position.
        votes += BalancerALCXWETHLPVotes(account);
        // 6. Get the naked and staked (in Curve, Convex and Frax) ALCX/FraxBP Curve LP.
        votes += CurveALCXFraxBPLPVotes(account);
    }

    function ALCXVotes(address account) public view returns (uint256 votes) {
        votes = ALCX.balanceOf(account);
        votes += alchemixStakingPools.getStakeTotalDeposited(account, 1);
    }

    function gALCXVotes(address account) public view returns (uint256 votes) {
        votes = gALCX.balanceOf(account);
    }

    function tALCXVotes(address account) public view returns (uint256 votes) {
        votes = tALCX.balanceOf(account);
        votes += alchemixStakingPools.getStakeTotalDeposited(account, 8);
    }

    function SushiswapALCXWETHLPVotes(address account) public view returns (uint256 votes) {
        // Calculate how much ALCX in LP token the account owns.
        //
        // +================================+==============+
        // |        LP token balance        | ALCX balance |
        // +================================+==============+
        // | naked + staked account balance | ???          |
        // +--------------------------------+--------------+
        // | total supply in LP             | total in LP  |
        // +--------------------------------+--------------+
        //
        // alcxAccountBalanceInLP = (naked + staked LP tokens) * totalALCXInLP / LP total supply
        uint256 sushiLPBalance = sushiswapALCXLP.balanceOf(account);
        (uint256 stakedSushiLPBalance,) = masterChef.userInfo(0, account);
        (, uint256 reserveALCX,) = sushiswapALCXLP.getReserves();
        votes = (sushiLPBalance + stakedSushiLPBalance) * reserveALCX / sushiswapALCXLP.totalSupply();
    }

    function BalancerALCXWETHLPVotes(address account) public view returns (uint256 votes) {
        (, uint256[] memory b,) = balancerVault.getPoolTokens(balancerALCXPoolId);
        uint256 underlyingBalanceInLP = b[1];
        uint256 balancerLPTotalSupply = balancerALCXLP.totalSupply();
        uint256 balanceInBalancer = balancerALCXLP.balanceOf(account);
        uint256 balanceStakedInBalancer = balancerALCXLPStaking.balanceOf(account);
        uint256 balanceInAura = auraBalancerALCXLPVault.balanceOf(account);
        votes = (balanceInBalancer + balanceStakedInBalancer + balanceInAura) * underlyingBalanceInLP
            / balancerLPTotalSupply;
    }

    function CurveALCXFraxBPLPVotes(address account) public view returns (uint256 votes) {
        uint256 accountCurveLPBalance = account != convexVoter
            ? curveALCXFraxBPLP.balanceOf(account) + curveALCXFraxBPGauge.balanceOf(account)
                + convexALCXFraxBPRewardPool.balanceOf(account)
            // Set Convex votes to 0.
            : 0;
        votes = curveALCXFraxBPPool.calc_withdraw_one_coin(accountCurveLPBalance, 0);
    }
}
