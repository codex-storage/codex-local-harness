#!/usr/bin/env bash
set -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"

_prom_output=${PROM_TARGETS_DIR:-$(clh_output_folder "prometheus")}

prom_add() {
  local metrics_port="$1"\
    experiment_type="$2"\
    experiment_id="$3"\
    node="$4"\
    node_type="$5"

  mkdir -p "${_prom_output}"

  cat > "${_prom_output}/${metrics_port}-${experiment_type}-${experiment_id}-${node}-${node_type}.json" <<EOF
{
  "targets": ["host.docker.internal:${metrics_port}"],
  "labels": {
    "job": "${experiment_type}",
    "experiment_id": "${experiment_id}",
    "node": "${node}",
    "node_type": "${node_type}"
  }
}
EOF
}

prom_remove() {
  local metrics_port="$1"\
    experiment_type="$2"\
    experiment_id="$3"\
    node="$4"\
    node_type="$5"

  rm "${_prom_output}/${metrics_port}-${experiment_type}-${experiment_id}-${node}-${node_type}.json" || true
}
