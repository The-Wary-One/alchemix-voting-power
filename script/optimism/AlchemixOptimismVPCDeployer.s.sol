// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "../../lib/forge-std/src/Script.sol";

import {AlchemixOptimismVPC} from "../../src/optimism/AlchemixOptimismVPC.sol";

contract AlchemixOptimismVPCDeployer is Script {
    function run() external returns (AlchemixOptimismVPC) {
        vmSafe.broadcast();

        AlchemixOptimismVPC votingPowerCalculator = new AlchemixOptimismVPC();

        return votingPowerCalculator;
    }
}
