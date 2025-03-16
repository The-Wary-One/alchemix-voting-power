// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {UD60x18, ud, intoUint256} from "../../lib/prb/src/UD60x18.sol";

import {IAlchemixToken} from "../interfaces/Alchemix.sol";
import {IPool, IGauge} from "../interfaces/Lynex.sol";

contract AlchemixLineaVPC {
    /* --- Alchemix --- */
    IAlchemixToken constant ALCX = IAlchemixToken(0x303c4F39EA359155C698807168e9Dc3aA1dF2b95);
    /* --- Lynex --- */
    IPool constant lynexUsdcAlcxPool = IPool(0xaC73C5f3d110Bb051100cfD8Afa4aC4339f239E7);
    IGauge constant lynexUsdcAlcxGauge = IGauge(0x0D47192a891Caba2f7cc349DD4392d2A1fA5082a);

    /// @notice Get the voting power of `account`.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPower(address account) external view returns (uint256 votingPower) {
        // 1. Get the naked `ALCX` balance.
        votingPower = getVotingPowerInTokens(account);
        // 2. Get the naked and staked Lynex LPs voting power.
        votingPower += getVotingPowerInLynex(account);
    }

    /// @notice Get the naked `ALCX` voting power.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPowerInTokens(address account) public view returns (uint256 votingPower) {
        votingPower = ALCX.balanceOf(account);
    }

    /// @notice Get the naked and staked USDC/ALCX Lynex LP voting power.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPowerInLynex(address account) public view returns (uint256 votingPower) {
        UD60x18 nakedLPBalance = ud(lynexUsdcAlcxPool.balanceOf(account));
        UD60x18 stakedLPBalanceInGauge = ud(lynexUsdcAlcxGauge.balanceOf(account));
        UD60x18 accountLPBalance = nakedLPBalance + stakedLPBalanceInGauge;

        UD60x18 lpTotalSupply = ud(lynexUsdcAlcxPool.totalSupply());
        UD60x18 alcxInPool = ud(lynexUsdcAlcxPool.reserve1());

        UD60x18 vp = accountLPBalance / lpTotalSupply * alcxInPool;

        votingPower = intoUint256(vp);
    }
}
