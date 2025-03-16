// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Script} from "../../lib/forge-std/src/Script.sol";

import {AlchemixLineaVPC} from "../../src/linea/AlchemixLineaVPC.sol";

contract AlchemixLineaVPCDeployer is Script {
    function run() external returns (AlchemixLineaVPC) {
        vmSafe.broadcast();

        AlchemixLineaVPC votingPowerCalculator = new AlchemixLineaVPC();

        return votingPowerCalculator;
    }
}
