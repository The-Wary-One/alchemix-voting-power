#!/usr/bin/env bash

set -e

source .env

abi=$(jq -c '{abi: .abi}' ./out/AlchemixVotingPowerCalculator.sol/AlchemixVotingPowerCalculator.json)

address=$(jq -c \
    '{address: .transactions[0].contractAddress}' \
    ./broadcast/AlchemixVotingPowerCalculatorDeployer.s.sol/1/run-latest.json)

blocknumberhex=$(jq -rc \
    '.receipts[0].blockNumber' \
    ./broadcast/AlchemixVotingPowerCalculatorDeployer.s.sol/1/run-latest.json)

blocknumber=$(cast --to-base "${blocknumberhex}" 10)

printf '%s %s {"blockNumber": %i}' "${abi}" "${address}" "${blocknumber}" | jq --slurp add >./deployments/1/AlchemixVotingPowerCalculator.json
