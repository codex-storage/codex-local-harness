setup() {
  bats_require_minimum_version 1.12.0

  export LIB_SRC="${BATS_TEST_DIRNAME}/../src"
  load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load.bash"
  load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load.bash"

  source "${LIB_SRC}/process_monitor.bash"
}

@test "should not start process monitor twice" {
  assert_equal $(clh_monitor_state) "halted"

  assert clh_start_process_monitor
  assert_equal $(clh_monitor_state) "running"

  refute clh_start_process_monitor

  assert clh_stop_process_monitor
  assert_equal $(clh_monitor_state) "halted"
}

@test "should not stop the process monitor if it wasn't started" {
  refute clh_stop_process_monitor
}

@test "should keep track of process IDs" {
  assert clh_start_process_monitor

  clh_get_tracked_pids
  assert [ ${#result[@]} -eq 0 ]

  (
    while [ ! -f "${_procmon_output}/sync" ]; do
      sleep 0.1
    done
    clh_exit 0
  ) &
  clh_track_last_background_job
  p1=$!

  (
    while [ ! -f "${_procmon_output}/sync" ]; do
      sleep 0.1
    done
    clh_exit 0
  ) &
  clh_track_last_background_job
  p2=$!

  clh_get_tracked_pids
  assert [ ${#result[@]} -eq 2 ]

  touch "${_procmon_output}/sync"

  await "$p1"
  await "$p2"

  # This should be more than enough for the process monitor to
  # catch the exits. The alternative would be implementing temporal
  # predicates.
  sleep 1

  clh_get_tracked_pids
  assert [ ${#result[@]} -eq 0 ]

  clh_stop_process_monitor
}

@test "should stop the monitor and all other processes if one process fails" {
  assert clh_start_process_monitor

  (
    while [ ! -f "${_procmon_output}/sync" ]; do
      sleep 0.1
    done
    clh_exit 1
  ) &
  clh_track_last_background_job
  p1=$!

  (
    while [ ! -f "${_procmon_output}/sync" ]; do
      sleep 1
    done
    clh_exit 0
  ) &
  clh_track_last_background_job
  p2=$!

  touch "${_procmon_output}/sync"

  await "$p1"
  await "$p2"

  sleep 1

  assert_equal $(clh_monitor_state) "halted_process_failure"
}