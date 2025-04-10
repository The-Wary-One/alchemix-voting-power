#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

declare -r contract_name="${1}"
declare -r chain_name="${2}"

# `cd` to project root.
cd "$(dirname "${0}")/../"

# Deploy the ${contract_name} using the first anvil account.
printf '🚀 Deploy the AlchemixVotingPowerCalculator contract...\n'
FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}" forge script "script/${chain_name}/${contract_name}Deployer.s.sol:${contract_name}Deployer" \
    -f 'http://localhost:8545' \
    --private-key '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' \
    --broadcast

# Generate a Hardhat-like deployment file.
printf '⚙ Generate the deployment file...\n'
./script/generate-deployment-file.sh "${contract_name}" '31337'
