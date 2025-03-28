// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Script} from "../../lib/forge-std/src/Script.sol";

import {AlchemixVotingPowerCalculator} from "../../src/mainnet/AlchemixVotingPowerCalculator.sol";

contract AlchemixVotingPowerCalculatorDeployer is Script {
    function run() external returns (AlchemixVotingPowerCalculator) {
        vmSafe.broadcast();

        AlchemixVotingPowerCalculator votingPowerCalculator = new AlchemixVotingPowerCalculator();

        return votingPowerCalculator;
    }
}
