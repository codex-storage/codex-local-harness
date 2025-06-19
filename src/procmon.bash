#!/usr/bin/env bash
LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/config.bash
source "${LIB_SRC}/config.bash"
# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"

_pm_output=$(clh_output_folder "pm")
_pm_pid=""

_pm_init_output() {
  rm -rf "${_pm_output}" || true
  mkdir -p "${_pm_output}"
}

# Starts the process monitor.
# Returns:
#   1 if the process monitor is already running
#   0 otherwise
pm_start() {
  _pm_assert_state_not "running" || return 1
  _pm_init_output

  echoerr "[procmon] starting process monitor"

  export _pm_output
  (
    _pm_pid=${BASHPID}
    while true; do
      pm_known_pids
      for pid in "${result[@]}"; do
        if kill -0 "${pid}"; then
          continue
        fi

        exit_code=$(cat "${_pm_output}/${pid}.pid")
        if [ $? -ne 0 ]; then
          echoerr "[procmon] ${pid} died with unknown exit code. Aborting."
          _pm_halt "halted_no_return"
        fi

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

# Tracks the last job started by the shell as part of a monitored group.
# If a tracked process dies:
#  1. without an error code (e.g. it is killed);
#  2. with a non-zero error code.
# Then all processes in the process group and their descendants (with caveats)
# are also killed. This makes sure that the harness does not leave processes
# behind.
#
# Returns:
#   1 if the process monitor is not running
#   0 otherwise
pm_track_last_job() {
  _pm_assert_state "running" || return 1

  local pid=$!
  if [ ! -f "${_pm_output}/${pid}.pid" ]; then
    touch "${_pm_output}/${pid}.pid"
  fi
}

# Stops tracking a given PID.
# Arguments:
#   $1: PID to stop tracking
# Returns:
#   1 if the process monitor is not running
#   0 otherwise
# Note:
#   This function is flaky. The process monitor
#   might still see the PID as tracked after this
#   function returns for a short period of time,
#   so do not rely too much on it.
pm_stop_tracking() {
  _pm_assert_state "running" || return 1

  local pid=$1
  rm -rf "${_pm_output}/${pid}.pid" || true
}

# Returns the list of PIDs being tracked by the process monitor by
# setting the `result` variable.
# Returns:
#   1 if the process monitor is not running
#   0 otherwise
pm_known_pids() {
  _pm_assert_state "running" || return 1

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
  _pm_assert_state "running" || return 1

  pm_known_pids
  pids=("${result[@]}")

  for pid in "${pids[@]}"; do
    pm_kill_rec "${pid}"
  done

  echo "$1" > "${_pm_output}/pm_exit_code"

  # last but not least, harakiri
  pm_kill_rec "$_pm_pid"
}

# Stops the process monitor, killing the entire process group.
# Returns:
#   1 if the process monitor is not running
#   0 otherwise
pm_stop() {
  _pm_halt "halted"
}

pm_join() {
  await "$_pm_pid" "$1"
}

pm_job_exit() {
  local pid_file="${_pm_output}/${BASHPID}.pid" exit_code=$1
  # If the process is not tracked, don't write down an exit code.
  if [ ! -f "$pid_file" ]; then
    echoerr "[procmon] no PID file found for process $BASHPID"
  else
    echo "$exit_code" > "${_pm_output}/${BASHPID}.pid"
  fi
  exit "$exit_code"
}

pm_kill_rec() {
  local parent="$1" descendant

  pm_list_descendants "$parent"
  for descendant in "${result[@]}"; do
    echo "[procmon] killing process $descendant"
    kill -s TERM "$descendant" 2> /dev/null || true
  done

  return 0
}

pm_list_descendants() {
  result=()
  _pm_list_descendants "$@"
}

_pm_list_descendants() {
  local parent="$1"
  result+=("${parent}")

  for pid in $(ps -o pid --ppid "$parent" | tail -n +2 | tr -d ' '); do
    _pm_list_descendants "$pid"
  done
}

_pm_assert_state_not() {
  local state="$1" current_state
  current_state=$(pm_state)

  if [ "$current_state" = "$state" ]; then
    echoerr "[procmon] illegal state: $current_state"
    return 1
  fi
}

_pm_assert_state() {
  local state="$1" current_state
  current_state=$(pm_state)

  if [ "$current_state" != "$state" ]; then
    echoerr "[procmon] illegal state: $current_state"
    return 1
  fi
}
