#!/usr/bin/env bash

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"

exp_start() {
  _experiment_type="$1"
  # FIXME: this is pretty clumsy/confusing. We're "initing" the
  #   harness just so it sets the base output folder, and then
  #   "initing" it again.
  if [ -z "${_clh_output}" ]; then
    clh_init
  fi

  clh_init "${_clh_output}/${_experiment_type}-$(date +%s)-${RANDOM}" || return 1
}
