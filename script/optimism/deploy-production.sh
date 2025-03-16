#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

cd "$(dirname "${0}")"

RPC_URL="${RPC_OPTIMISM}" ../deploy-production.sh 'AlchemixOptimismVPC' 'optimism' 10
