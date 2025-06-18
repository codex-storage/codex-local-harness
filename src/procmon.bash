#!/usr/bin/env bash

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/config.bash
source "${LIB_SRC}/config.bash"
# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"

_pm_output=$(clh_output_folder "pm")
_pm_pid=""
_pm_stop_mode=""

_pm_init_output() {
  rm -rf "${_pm_output}" || true
  mkdir -p "${_pm_output}"
}

pm_start() {
  if [ -n "$_pm_pid" ]; then
    echoerr "[procmon] process monitor already started"
    return 1
  fi

  _pm_init_output
  _pm_stop_mode="$1"

  local pid=$$
  _pm_pgid=$(ps -o pgid= -p ${pid} | sed 's/ //g')
  export _pm_pgid
  export _pm_output

  echoerr "[procmon] starting process monitor"

  (
    _pm_pid=${BASHPID}
    while true; do
      pm_known_pids
      for pid in "${result[@]}"; do
        if kill -0 "${pid}"; then
          continue
        fi

        exit_code=$(cat "${_pm_output}/${pid}.pid")
        if [ -z "$exit_code" ]; then
          echoerr "[procmon] ${pid} died with unknown exit code. Aborting."
          _pm_halt "halted_no_return"
        fi

        if [ "$exit_code" -eq 0 ]; then
          echoerr "[procmon] ${pid} died with exit code $exit_code."
          rm "${_pm_output}/${pid}.pid"
          continue
        fi

        echoerr "[procmon] ${pid} is dead with exit code $exit_code. Aborting."
        _pm_halt "halted_process_failure"
      done
      sleep 1
    done
  ) &
  _pm_pid=$!
  echoerr "[procmon] started with PID $_pm_pid"
  return 0
}

pm_track_last_job() {
  local pid=$!
  if [ ! -f "${_pm_output}/${pid}.pid" ]; then
    touch "${_pm_output}/${pid}.pid"
  fi
}

pm_known_pids() {
  local base_name pid
  result=()
  for pid_file in "${_pm_output}"/*.pid; do
    [[ -f "${pid_file}" ]] || continue # null glob
    base_name=$(basename "${pid_file}")
    pid=${base_name%.pid}
    result+=("${pid}")
  done
}

pm_state() {
  # No process ID, process monitor never ran.
  if [ -z "$_pm_pid" ]; then
    echo "halted"
    return 0
  fi

  # Process ID is set and process is running.
  if kill -0 "$_pm_pid"; then
    echo "running"
    return 0
  fi

  if [ -f "${_pm_output}/pm_exit_code" ]; then
    exit_code=$(cat "${_pm_output}/pm_exit_code")
    echo "$exit_code"
    return 0
  fi

  echo "error_no_exit_code"
  return 1
}

_pm_halt() {
  if [ -z "$_pm_pid" ]; then
    echoerr "[procmon] process monitor not started"
    return 1
  fi

  if ! kill -0 "$_pm_pid"; then
    echoerr "[procmon] process monitor not running"
    return 1
  fi

  echo "$1" > "${_pm_output}/pm_exit_code"

  if [ "$_pm_stop_mode" = "kill_on_exit" ]; then
    echoerr "[procmon] stop process group. This will halt the script."
    kill -s TERM "-$_pm_pgid"
  else
    echoerr "[procmon] stop monitor only. Children will be left behind."
    kill -s TERM "$_pm_pid"
    await "$_pm_pid"
    return 0
  fi
}

pm_stop() {
  _pm_halt "halted"
}

pm_job_exit() {
  exit_code=$1
  echoerr "[procmon] $BASHPID exit with code $exit_code"
  echo "$exit_code" > "${_pm_output}/${BASHPID}.pid"
  exit "$exit_code"
}