#!/usr/bin/env bash

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./config.bash
source "${LIB_SRC}/config.bash"
# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

_procmon_output=$(clh_output_folder "procmon")
_procmon_pid=""
_procmon_stop_mode=""

_procmon_init_output() {
  rm -rf "${_procmon_output}" || true
  mkdir -p "${_procmon_output}"
}

clh_start_process_monitor() {
  if [ -n "$_procmon_pid" ]; then
    echoerr "[procmon] process monitor already started"
    return 1
  fi

  _procmon_init_output
  _procmon_stop_mode="$1"

  local pid=$$
  _pgid=$(ps -o pgid= -p ${pid} | sed 's/ //g')
  export _pgid
  export _procmon_output

  echoerr "[procmon] start"

  (
    _procmon_pid=${BASHPID}
    while true; do
      clh_get_tracked_pids
      for pid in "${result[@]}"; do
        if kill -0 "${pid}"; then
          continue
        fi

        exit_code=$(cat "${_procmon_output}/${pid}.pid")
        if [ -z "$exit_code" ]; then
          echoerr "[procmon] ${pid} died with unknown exit code. Aborting."
          _clh_halt "halted_no_return"
        fi

        if [ "$exit_code" -eq 0 ]; then
          echoerr "[procmon] ${pid} died with exit code $exit_code."
          rm "${_procmon_output}/${pid}.pid"
          continue
        fi

        echoerr "[procmon] ${pid} is dead with exit code $exit_code. Aborting."
        _clh_halt "halted_process_failure"
      done
      sleep 1
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

clh_monitor_state() {
  # No process ID, process monitor never ran.
  if [ -z "$_procmon_pid" ]; then
    echo "halted"
    return 0
  fi

  # Process ID is set and process is running.
  if kill -0 "$_procmon_pid"; then
    echo "running"
    return 0
  fi

  if [ -f "${_procmon_output}/procmon_exit_code" ]; then
    exit_code=$(cat "${_procmon_output}/procmon_exit_code")
    echo "$exit_code"
    return 0
  fi

  echo "error_no_exit_code"
  return 1
}

_clh_halt() {
  if [ -z "$_procmon_pid" ]; then
    echoerr "[procmon] process monitor not started"
    return 1
  fi

  if ! kill -0 "$_procmon_pid"; then
    echoerr "[procmon] process monitor not running"
    return 1
  fi

  echo "$1" > "${_procmon_output}/procmon_exit_code"

  if [ "$_procmon_stop_mode" = "kill_on_exit" ]; then
    echoerr "[procmon] stop process group. This will halt the script."
    kill -s TERM "-$_pgid"
  else
    echoerr "[procmon] stop monitor only. Children will be left behind."
    kill -s TERM "$_procmon_pid"
    await "$_procmon_pid"
    return 0
  fi
}

clh_stop_process_monitor() {
  _clh_halt "halted"
}

clh_exit() {
  exit_code=$1
  echoerr "[procmon] $BASHPID exit with code $exit_code"
  echo "$exit_code" > "${_procmon_output}/${BASHPID}.pid"
  exit "$exit_code"
}