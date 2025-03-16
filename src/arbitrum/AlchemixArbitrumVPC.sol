//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {UD60x18, ud, intoUint256} from "../../lib/prb/src/UD60x18.sol";

import {IAlchemixToken} from "../interfaces/Alchemix.sol";
import {IPool, IGauge} from "../interfaces/Ramses.sol";

contract AlchemixArbitrumVPC {
    /* --- Alchemix --- */
    IAlchemixToken constant ALCX = IAlchemixToken(0x27b58D226fe8f792730a795764945Cf146815AA7);
    /* --- Ramses --- */
    IPool constant ramsesAlethAlcxPool = IPool(0x9C99764Ad164360cf85EdA42Fa2F4166B6CBA2A4);
    IGauge constant ramsesAlethAlcxGauge = IGauge(0xbAAD0fA7c22F81f407a416b9bF7E0148e87BFb59);
    IPool constant ramsesAlcxWethPool = IPool(0x531633a03f96DEb1C68EF02589c010A543aDbef2);
    IGauge constant ramsesAlcxWethGauge = IGauge(0x41d6F80c44a208e0DFd44a68357B8452028a078d);

    /// @notice Get the voting power of `account`.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPower(address account) external view returns (uint256 votingPower) {
        // 1. Get the naked `ALCX` balance.
        votingPower = getVotingPowerInTokens(account);
        // 2. Get the naked and staked Ramses LPs voting power.
        votingPower += getVotingPowerInRamses(account);
    }

    /// @notice Get the naked `ALCX` voting power.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPowerInTokens(address account) public view returns (uint256 votingPower) {
        votingPower = ALCX.balanceOf(account);
    }

    /// @notice Get the naked and staked ALETH/ALCX and ALCX/WETH Ramses LP voting power.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPowerInRamses(address account) public view returns (uint256 votingPower) {
        // Get the ALETH/ALCX Ramses LP voting power.
        {
            UD60x18 nakedLPBalance = ud(ramsesAlethAlcxPool.balanceOf(account));
            UD60x18 stakedLPBalanceInGauge = ud(ramsesAlethAlcxGauge.balanceOf(account));
            UD60x18 accountLPBalance = nakedLPBalance + stakedLPBalanceInGauge;

            UD60x18 lpTotalSupply = ud(ramsesAlethAlcxPool.totalSupply());
            UD60x18 alcxInPool = ud(ramsesAlethAlcxPool.reserve1());

            UD60x18 vp = accountLPBalance / lpTotalSupply * alcxInPool;

            votingPower = intoUint256(vp);
        }

        // Get the ALCX/WETH Ramses LP voting power.
        {
            UD60x18 nakedLPBalance = ud(ramsesAlcxWethPool.balanceOf(account));
            UD60x18 stakedLPBalanceInGauge = ud(ramsesAlcxWethGauge.balanceOf(account));
            UD60x18 accountLPBalance = nakedLPBalance + stakedLPBalanceInGauge;

            UD60x18 lpTotalSupply = ud(ramsesAlcxWethPool.totalSupply());
            UD60x18 alcxInPool = ud(ramsesAlcxWethPool.reserve0());

            UD60x18 vp = accountLPBalance / lpTotalSupply * alcxInPool;

            votingPower += intoUint256(vp);
        }
    }
}
