#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

cd "$(dirname "${0}")"

RPC_URL="${RPC_ARBITRUM}" BLOCK_NUMBER="${BLOCK_NUMBER_ARBITRUM}" ../start-fork.sh
