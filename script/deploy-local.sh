#!/usr/bin/env bash
set -e

source .env

# Deploy the AlchemixVotingPower using the first anvil account.
forge script script/DeployAlchemixVotingPower.s.sol:DeployAlchemixVotingPower \
    -f "http://localhost:8545" \
    --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
    --broadcast

# Generate a Hardhat-like deployment file.
./script/generate-deployment-file-local.sh
