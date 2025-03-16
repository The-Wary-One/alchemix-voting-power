// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Script} from "../../lib/forge-std/src/Script.sol";

import {AlchemixArbitrumVPC} from "../../src/arbitrum/AlchemixArbitrumVPC.sol";

contract AlchemixArbitrumVPCDeployer is Script {
    function run() external returns (AlchemixArbitrumVPC) {
        vmSafe.broadcast();

        AlchemixArbitrumVPC votingPowerCalculator = new AlchemixArbitrumVPC();

        return votingPowerCalculator;
    }
}
