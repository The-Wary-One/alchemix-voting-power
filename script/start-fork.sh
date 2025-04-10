#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}" anvil \
    --fork-url "${RPC_URL}" \
    --fork-block-number "${BLOCK_NUMBER}" \
    --fork-chain-id 31337 \
    --block-time 20
