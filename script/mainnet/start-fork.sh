#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

cd "$(dirname "${0}")"

RPC_URL="${RPC_MAINNET}" BLOCK_NUMBER="${BLOCK_NUMBER_MAINNET}" ../start-fork.sh
