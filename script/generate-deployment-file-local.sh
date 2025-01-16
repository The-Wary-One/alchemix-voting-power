#!/usr/bin/env bash
set -e

source .env

abi=$(jq -c "{abi: .abi}" ./out/AlchemixVotingPowerCalculator.sol/AlchemixVotingPowerCalculator.json)
address=$(jq -c \
    "{address: .transactions[0].contractAddress}" \
    ./broadcast/AlchemixVotingPowerCalculatorDeployer.s.sol/31337/run-latest.json)
blocknumberhex=$(jq -rc \
    ".receipts[0].blockNumber" \
    ./broadcast/AlchemixVotingPowerCalculatorDeployer.s.sol/31337/run-latest.json)
blocknumber=$(cast --to-base $blocknumberhex 10)
echo "$abi $address {\"blockNumber\": $blocknumber}" | jq -s add > ./deployments/31337/AlchemixVotingPowerCalculator.json
