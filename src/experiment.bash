#!/usr/bin/env bash
set -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"
# shellcheck source=./src/codex.bash
source "${LIB_SRC}/codex.bash"
# shellcheck source=./src/prometheus.bash
source "${LIB_SRC}/prometheus.bash"

_experiment_type=""
_experiment_id=""

exp_start() {
  local experiment_id experiment_type="$1"

  experiment_id="$(date +%s)-${RANDOM}" || return 1

  # FIXME: this is pretty clumsy/confusing. We're "initing" the
  #   harness just so it sets the base output folder, and then
  #   "initing" it again.
  if [ -z "${_clh_output}" ]; then
    clh_init
  fi

  _experiment_id="${experiment_id}"
  _experiment_type="${experiment_type}"

  clh_init "${_clh_output}/${_experiment_id}" || return 1
  cdx_add_defaultopts "--metrics"

  pm_register_callback "codex" _codex_target_changed
}

_codex_target_changed() {
  local event="$1"
  if [ "$event" = "start" ]; then
    shift 3
    _add_target "$@"
  elif [ "$event" = "exit" ]; then
    shift 4
    _remove_target "$@"
  fi
}

_add_target() {
  local node_index="$1" metrics_port
  metrics_port=$(_cdx_metrics_port "$node_index") || return 1

  prom_add "${metrics_port}" "${_experiment_type}" "${_experiment_id}"\
    "${node_index}" "codex"
}

_remove_target() {
  local node_index="$1" metrics_port
  metrics_port=$(_cdx_metrics_port "$node_index") || return 1

  prom_remove "${metrics_port}" "${_experiment_type}" "${_experiment_id}"\
    "${node_index}" "codex"
}
