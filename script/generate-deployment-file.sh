#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

declare -r contract_name="${1}"
declare -ri chain_id=${2}

# `cd` to project root.
cd "$(dirname "${0}")/../"

abi=$(jq --compact-output '{abi: .abi}' "./out/${contract_name}.sol/${contract_name}.json")

address=$(jq --compact-output \
    '{address: .transactions[0].contractAddress}' \
    "./broadcast/${contract_name}Deployer.s.sol/${chain_id}/run-latest.json")

blocknumberhex=$(jq --raw-output --compact-output \
    '.receipts[0].blockNumber' \
    "./broadcast/${contract_name}Deployer.s.sol/${chain_id}/run-latest.json")

blocknumber=$(cast --to-base "${blocknumberhex}" 10)

# Create the chain deployment directory if it doesn't exist.
mkdir -p "./deployments/${chain_id}/"
# Merge `abi`, `address` and `blockNumber` into a single JSON dictionnary.
printf '%s %s {"blockNumber": %i}\n' "${abi}" "${address}" "${blocknumber}" | jq --slurp add >"./deployments/${chain_id}/${contract_name}.json"
