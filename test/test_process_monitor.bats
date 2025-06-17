setup() {
  bats_require_minimum_version 1.12.0

  export LIB_SRC="${BATS_TEST_DIRNAME}/../src"
  load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load.bash"
  load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load.bash"

  source "${LIB_SRC}/process_monitor.bash"
}

@test "should not start process monitor twice" {
  assert clh_start_process_monitor
  refute clh_start_process_monitor
  assert clh_stop_process_monitor "monitor_only"
}

@test "should not stop the process monitor if it wasn't started" {
  refute clh_stop_process_monitor
}

@test "should keep track of process IDs" {
  echo "hi"
  assert clh_start_process_monitor

  clh_get_tracked_pids
  assert [ ${#result[@]} -eq 0 ]

  (
    while true; do
      sleep 0.1
    done
  ) &
  clh_track_last_background_job
  p1=$!

  (
    while true; do
      sleep 0.1
    done
  ) &
  clh_track_last_background_job
  p2=$!

  clh_get_tracked_pids
  assert [ ${#result[@]} -eq 2 ]

  kill -s TERM "$p1"
  kill -s TERM "$p2"

  echo "Kill issued" > killissued

  # This will hang the bats runner for some reason.
  await "$p1"
  await "$p2"

  # This should be more than enough for the process monitor to
  # catch the exits. The alternative would be implementing temporal
  # predicates.
  sleep 3

  clh_get_tracked_pids
  assert [ ${#result[@]} -eq 0 ]

  clh_stop_process_monitor "monitor_only"
}
