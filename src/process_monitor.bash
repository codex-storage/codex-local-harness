#!/usr/bin/env bash

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./config.bash
source "${LIB_SRC}/config.bash"
# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

_procmon_output=$(clh_output_folder "procmon")
_procmon_pid=""

_procmon_init_output() {
  rm -rf "${_procmon_output}" || true
  mkdir -p "${_procmon_output}"
}

clh_start_process_monitor() {
  _procmon_init_output

  if [ -n "$_procmon_pid" ]; then
    echoerr "[procmon] process monitor already started"
    return 1
  fi

  local pid=$$
  _pgid=$(ps -o pgid= -p ${pid} | sed 's/ //g')
  export _pgid
  export _procmon_output

  echoerr "[procmon] start"

  (
    shutdown=false
    while ! $shutdown; do
      clh_get_tracked_pids
      for pid in "${result[@]}"; do
        if ! kill -0 "${pid}"; then
          echoerr "[procmon] ${pid} is dead"
          rm "${_procmon_output}/${pid}.pid"
        fi
        sleep 1
      done
    done
  ) &
  _procmon_pid=$!
  echoerr "[procmon] started with PID $_procmon_pid"
  return 0
}

clh_track_last_background_job() {
  local pid=$!
  if [ ! -f "${_procmon_output}/${pid}.pid" ]; then
    touch "${_procmon_output}/${pid}.pid"
  fi
}

clh_get_tracked_pids() {
  result=()
  for pid_file in "${_procmon_output}"/*.pid; do
    [[ -f "${pid_file}" ]] || continue # null glob
    base_name=$(basename "${pid_file}")
    pid=${base_name%.pid}
    result+=("${pid}")
  done
}

clh_stop_process_monitor() {
  if [ -z "$_procmon_pid" ]; then
    echoerr "[procmon] process monitor not started"
    return 1
  fi

  if ! kill -0 "$_procmon_pid"; then
    echoerr "[procmon] process monitor not running"
    return 1
  fi

  if [ "$1" = "monitor_only" ]; then
    echoerr "[procmon] stop monitor only. Children will be left behind."
    kill -s TERM "$_procmon_pid"
    await "$_procmon_pid"
    return 0
  else
    echoerr "[procmon] stop process group. This will halt the script."
    kill -s TERM "-$_pgid"
  fi
}