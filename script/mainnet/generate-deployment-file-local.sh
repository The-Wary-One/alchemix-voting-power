#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

abi=$(jq --compact-output '{abi: .abi}' ./out/AlchemixVotingPowerCalculator.sol/AlchemixVotingPowerCalculator.json)

address=$(jq -c \
    '{address: .transactions[0].contractAddress}' \
    ./broadcast/AlchemixVotingPowerCalculatorDeployer.s.sol/31337/run-latest.json)

blocknumberhex=$(jq --raw-output --compact-output \
    '.receipts[0].blockNumber' \
    ./broadcast/AlchemixVotingPowerCalculatorDeployer.s.sol/31337/run-latest.json)

blocknumber=$(cast --to-base "${blocknumberhex}" 10)

printf '%s %s {"blockNumber": %i}\n' "${abi}" "${address}" "${blocknumber}" | jq --slurp add >./deployments/31337/AlchemixVotingPowerCalculator.json
