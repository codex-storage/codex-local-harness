#!/usr/bin/env bash
set -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"
# shellcheck source=./src/codex.bash
source "${LIB_SRC}/codex.bash"

_experiment_type=""
_experiment_id=""

exp_start() {
  local experiment_id experiment_type="$1"

  experiment_id="${experiment_type}-$(date +%s)-${RANDOM}" || return 1

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
}
