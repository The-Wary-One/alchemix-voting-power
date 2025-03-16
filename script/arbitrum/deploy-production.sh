#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

cd "$(dirname "${0}")"

RPC_URL="${RPC_ARBITRUM}" ../deploy-production.sh 'AlchemixArbitrumVPC' 'arbitrum' 42161
