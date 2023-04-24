#!/usr/bin/env bash
set -e

source .env

# Start a local anvil instance forked from Mainnet
anvil \
    --fork-url "${RPC_MAINNET}" \
    --fork-block-number "${BLOCK_NUMBER_MAINNET}" \
    --fork-chain-id 31337 \
    --block-time 20
