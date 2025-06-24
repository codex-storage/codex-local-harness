#!/usr/bin/env bash
#
# k-nodes runs a Codex network with k nodes in which a file is uploaded to
# node zero and then the remainder k - 1 nodes download it concurrently.
#
# Outputs download times to a log file.
#
# Usage: k-node.sh <node_count> <repetitions> <output_log> <file_sizes...>
#
# Example: k-node.sh 5 10 ./k-node-5-10.csv 100 200 500
set -e -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${SCRIPT_DIR}/../src/clh"

node_count="${1:-2}"
repetitions="${2:-1}"
output_log="${3:-"${OUTPUTS}/k-node-$(date +%s)-${RANDOM}.csv"}"
shift 3
file_sizes=("$@")

exp_start "k-node"

# TODO: procmon management should be moved into
#  experiment lifecycle management.
trap pm_stop EXIT INT TERM
pm_start

cdx_launch_network "${node_count}"

for i in $(seq 1 "${repetitions}"); do
  for file_size in "${file_sizes[@]}"; do
    file_name=$(cdx_generate_file "${file_size}")
    cid=$(cdx_upload_file "0" "${file_name}")

    cdx_log_timings_start "${output_log}" "${file_size},${i},${cid}"

    handles=()
    for j in $(seq 1 "${node_count}"); do
      cdx_download_file_async "$j" "$cid"
      # shellcheck disable=SC2128
      handles+=("$result")
    done

    await_all "${handles[@]}"

    cdx_log_timings_end
  done
done
