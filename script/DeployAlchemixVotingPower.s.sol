// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";

import {AlchemixVotingPower} from "../src/AlchemixVotingPower.sol";

contract DeployAlchemixVotingPower is Script {

    function run() external returns (AlchemixVotingPower) {
        vmSafe.broadcast();

        AlchemixVotingPower votingPower = new AlchemixVotingPower();

        return votingPower;
    }
}
