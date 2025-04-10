#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

cd "$(dirname "${0}")"

FOUNDRY_PROFILE=linea RPC_URL="${RPC_LINEA}" ../deploy-production.sh 'AlchemixLineaVPC' 'linea' 59144
