#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

cd "$(dirname "${0}")"

../deploy-local.sh 'AlchemixLineaVPC' 'linea'
