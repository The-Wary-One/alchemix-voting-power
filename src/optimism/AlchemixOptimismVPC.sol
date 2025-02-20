//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";
import {UD60x18, ud, intoUint256} from "../../lib/prb/src/UD60x18.sol";

import {IAlchemixToken} from "../interfaces/Alchemix.sol";
import {IBeefyVaultV7} from "../interfaces/Beefy.sol";
import {IGauge, IPool} from "../interfaces/Velodrome.sol";

contract AlchemixOptimismVPC {
    /* --- Alchemix --- */
    IAlchemixToken constant ALCX = IAlchemixToken(0xE974B9b31dBFf4369b94a1bAB5e228f35ed44125);
    /* --- Velodrome --- */
    IPool constant veloUsdcAlcxPool = IPool(0x4B322314d6F7239F094f40d93e7d9C4A3081c625);
    IGauge constant veloUsdcAlcxGauge = IGauge(0x8686cb49a95CD78F5fDF916c6F339F1256989967);
    IBeefyVaultV7 constant beefyVault = IBeefyVaultV7(0x305aFC012538beBD12b162192e58d911D8Ab1B31);

    /// @notice Get the voting power of `account`.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPower(address account) external view returns (uint256 votingPower) {
        // 1. Get the naked `ALCX` balance.
        votingPower = getVotingPowerInTokens(account);
        // 2. Get the naked and staked (in Velodrome and Beefy) USDC/ALCX Velodrome LP voting power.
        votingPower += getVotingPowerInVelodrome(account);
    }

    /// @notice Get the naked `ALCX` voting power.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPowerInTokens(address account) public view returns (uint256 votingPower) {
        votingPower = ALCX.balanceOf(account);
    }

    /// @notice Get the naked and staked (in Velodrome and Beefy) USDC/ALCX Velodrome LP voting power.
    ///
    /// @param account The target account.
    /// @return votingPower The calculated voting power.
    function getVotingPowerInVelodrome(address account) public view returns (uint256 votingPower) {
        UD60x18 nakedLPBalance = ud(veloUsdcAlcxPool.balanceOf(account));
        UD60x18 stakedLPBalanceInGauge = ud(veloUsdcAlcxGauge.balanceOf(account));
        UD60x18 stakedLPBalanceInBeefy = ud(beefyVault.balanceOf(account)) * ud(beefyVault.getPricePerFullShare());
        UD60x18 accountLPBalance = nakedLPBalance + stakedLPBalanceInGauge + stakedLPBalanceInBeefy;

        UD60x18 lpTotalSupply = ud(veloUsdcAlcxPool.totalSupply());
        UD60x18 alcxInPool = ud(veloUsdcAlcxPool.reserve1());

        UD60x18 vp = accountLPBalance / lpTotalSupply * alcxInPool;

        return intoUint256(vp);
    }
}
