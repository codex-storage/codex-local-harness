#!/usr/bin/env bash
set -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/config.bash
source "${LIB_SRC}/config.bash"
# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"
# shellcheck source=./src/procmon.bash
source "${LIB_SRC}/procmon.bash"

# Codex binary
if [ -z "${CODEX_BINARY}" ]; then
  _cdx_binary="$(command -v codex)"
else
  _cdx_binary="${CODEX_BINARY}"
fi

if [ ! -f "${_cdx_binary}" ]; then
  echoerr "Error: no valid Codex binary found"
  exit 1
fi

# Output folders
_cdx_output=$(clh_output_folder "codex")
_cdx_genfiles="${_cdx_output}/genfiles"
_cdx_downloads="${_cdx_output}/downloads"
_cdx_uploads="${_cdx_output}/uploads"
_cdx_logs="${_cdx_output}/logs"
_cdx_data="${_cdx_output}/data"

# Base ports and timeouts
_cdx_base_api_port=8080
_cdx_base_disc_port=8190
_cdx_base_metrics_port=8290
_cdx_node_start_timeout=30

# PID array for known Codex node processes
declare -A _cdx_pids

_cdx_api_port() {
  local node_index="$1"
  echo $((_cdx_base_api_port + node_index))
}

_cdx_disc_port() {
  local node_index="$1"
  echo $((_cdx_base_disc_port + node_index))
}

_cdx_metrics_port() {
  local node_index="$1"
  echo $((_cdx_base_metrics_port + node_index))
}

cdx_cmdline() {
  local node_index spr cdx_cmd="${_cdx_binary} --nat:none"

  node_index="$1"
  shift

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --bootstrap-node)
        shift
        spr="$1"
        cdx_cmd="${cdx_cmd} --bootstrap-node=$spr"
        ;;
      --metrics)
        cdx_cmd="${cdx_cmd} --metrics --metrics-port=$(_cdx_metrics_port "$node_index") --metrics-address=0.0.0.0"
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
" --api-port=$(_cdx_api_port "$node_index") --disc-port=$(_cdx_disc_port "$node_index") --log-level=INFO"
}

cdx_get_spr() {
  local node_index="$1" spr

  spr=$(curl --silent --fail "http://localhost:$(_cdx_api_port "$node_index")/api/codex/v1/debug/info" | grep -oe 'spr:[^"]\+')
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
  mkdir -p "${_cdx_genfiles}" || return 1
  mkdir -p "${_cdx_downloads}/codex-${node_index}" || return 1
  mkdir -p "${_cdx_uploads}/codex-${node_index}" || return 1
}

cdx_generate_file() {
  local size_mb="${1}" filename
  filename="${_cdx_genfiles}/file-$(date +%s).bin"

  echoerr "Generating file ${filename} of size ${size_mb}MB"
  dd if=/dev/urandom of="${filename}" bs=1M count="${size_mb}" || return 1
  echo "${filename}"
}

cdx_upload_file() {
  local node_index="$1" filename="$2" content_sha1 cid

  content_sha1=$(sha1 "$filename") || return 1

  echoerr "Uploading file ${filename} to node ${node_index}"

  cid=$(curl --silent --fail\
    -XPOST "http://localhost:$(_cdx_api_port "$node_index")/api/codex/v1/data"\
    -T "${filename}") || return 1

  echoerr "Upload SHA-1 is ${content_sha1}"

  echo "${content_sha1}" > "${_cdx_uploads}/codex-${node_index}/${cid}.sha1"
  echo "${cid}"
}

cdx_download_file() {
  local node_index="$1" cid="$2"
  curl --silent --fail\
    -XGET "http://localhost:$(_cdx_api_port "$node_index")/api/codex/v1/data/$cid/network/stream"\
    -o "${_cdx_downloads}/codex-${node_index}/$cid" || return 1
}

cdx_upload_sha1() {
  local node_index="$1" cid="$2"
  cat "${_cdx_uploads}/codex-${node_index}/${cid}.sha1" || return 1
}

cdx_download_sha1() {
  local node_index="$1" cid="$2"
  sha1 "${_cdx_downloads}/codex-${node_index}/$cid" || return 1
}