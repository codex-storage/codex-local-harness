#!/usr/bin/env bash
LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/config.bash
source "${LIB_SRC}/config.bash"
# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"
# shellcheck source=./src/procmon.bash
source "${LIB_SRC}/procmon.bash"

_cdx_output=$(clh_output_folder "codex")
_cdx_logs="${_cdx_output}/logs"
_cdx_data="${_cdx_output}/data"

if [ -z "${CODEX_BINARY}" ]; then
  run command -v codex
  _cdx_binary="${output}"
else
  _cdx_binary="${CODEX_BINARY}"
fi

if [ ! -f "${_cdx_binary}" ]; then
  echoerr "Error: no valid Codex binary found"
  exit 1
fi

_cdx_base_api_port=8080
_cdx_base_disc_port=8190
_cdx_base_metrics_port=8290

_cdx_node_start_timeout=30

declare -A _cdx_pids

cdx_cmdline() {
  local api_port\
    disc_port\
    metrics_port\
    spr\
    node_index\
    cdx_cmd="${_cdx_binary} --nat:none"

  node_index="$1"
  shift

  api_port=$((_cdx_base_api_port + node_index))
  disc_port=$((_cdx_base_disc_port + node_index))
  metrics_port=$((_cdx_base_metrics_port + node_index))

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --bootstrap-node)
        shift
        spr="$1"
        cdx_cmd="${cdx_cmd} --bootstrap-node=$spr"
        ;;
      --metrics)
        cdx_cmd="${cdx_cmd} --metrics --metrics-port=${metrics_port} --metrics-address=0.0.0.0"
        ;;
      *)
        echoerr "Error: unknown option $1"
        return 1
        ;;
    esac
    shift
  done

  if [[ "$node_index" -gt 0 && -z "$spr" ]]; then
    echoerr "Error: SPR is required for node $node_index"
    return 1
  fi

  # shellcheck disable=SC2140
  echo "${cdx_cmd}"\
" --log-file=${_cdx_logs}/codex-${node_index}.log --data-dir=${_cdx_data}/codex-${node_index}"\
" --api-port=${api_port} --disc-port=${disc_port} --log-level=INFO"
}

cdx_get_spr() {
  local node_index="$1" api_port spr
  api_port=$((_cdx_base_api_port + node_index))

  spr=$(curl --silent --fail "http://localhost:${api_port}/api/codex/v1/debug/info" | grep -oe 'spr:[^"]\+')
  if [[ -z "$spr" ]]; then
    echoerr "Error: unable to get SPR for node $node_index"
    return 1
  fi

  echo "${spr}"
}

cdx_launch_node() {
  _cdx_ensure_outputs 0 || return 1

  local codex_cmd
  codex_cmd=$(cdx_cmdline "$@") || return 1

  (
    $codex_cmd
    pm_job_exit $?
  )&
  pm_track_last_job
  _cdx_pids[$1]=$!

  cdx_ensure_ready "$@"
}

cdx_destroy_node() {
  local node_index="$1" wipe_data="${2:-false}" pid
  pid="${_cdx_pids[$node_index]}"
  if [ -z "$pid" ]; then
    echoerr "Error: no process ID for node $node_index"
    return 1
  fi

  # Prevents the whole process group from dying.
  pm_stop_tracking "$pid"
  pm_kill_rec "$pid"
  await "$pid" || return 1

  unset "_cdx_pids[$node_index]"

  if [ "$wipe_data" = true ]; then
    rm -rf "${_cdx_data}/codex-${node_index}"
    rm -rf "${_cdx_logs}/codex-${node_index}.log"
  fi
}

cdx_ensure_ready() {
  local node_index="$1" timeout=${2:-$_cdx_node_start_timeout} start="${SECONDS}"
  while true; do
    if cdx_get_spr "$node_index"; then
      echoerr "Codex node $node_index is ready."
      return 0
    fi

    if (( SECONDS - start > timeout )); then
      echoerr "Codex node $node_index did not start within ${timeout} seconds."
      return 1
    fi

    sleep 0.2
  done
}

_cdx_ensure_outputs() {
  local node_index="$1"
  mkdir -p "${_cdx_logs}" || return 1
  mkdir -p "${_cdx_data}/codex-${node_index}" || return 1
}