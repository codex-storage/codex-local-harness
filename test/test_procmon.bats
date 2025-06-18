setup() {
  load test_helper/common_setup
  common_setup

  source "${LIB_SRC}/procmon.bash"
}

@test "should not start process monitor twice" {
  assert_equal $(pm_state) "halted"

  assert pm_start
  assert_equal $(pm_state) "running"

  refute pm_start

  assert pm_stop
  assert_equal $(pm_state) "halted"
}

@test "should not stop the process monitor if it wasn't started" {
  refute pm_stop
}

@test "should keep track of process IDs" {
  assert pm_start

  pm_known_pids
  assert [ ${#result[@]} -eq 0 ]

  (
    while [ ! -f "${_pm_output}/sync" ]; do
      sleep 0.1
    done
    pm_job_exit 0
  ) &
  pm_track_last_job
  p1=$!

  (
    while [ ! -f "${_pm_output}/sync" ]; do
      sleep 0.1
    done
    pm_job_exit 0
  ) &
  pm_track_last_job
  p2=$!

  pm_known_pids
  assert [ ${#result[@]} -eq 2 ]

  touch "${_pm_output}/sync"

  await "$p1"
  await "$p2"

  # This should be more than enough for the process monitor to
  # catch the exits. The alternative would be implementing temporal
  # predicates.
  sleep 1

  pm_known_pids
  assert [ ${#result[@]} -eq 0 ]

  pm_stop
}

@test "should stop the monitor and all other processes if one process fails" {
  assert pm_start

  (
    while [ ! -f "${_pm_output}/sync" ]; do
      sleep 0.1
    done
    pm_job_exit 1
  ) &
  pm_track_last_job
  p1=$!

  (
    while [ ! -f "${_pm_output}/sync" ]; do
      sleep 1
    done
    pm_job_exit 0
  ) &
  pm_track_last_job
  p2=$!

  touch "${_pm_output}/sync"

  await "$p1"
  await "$p2"

  sleep 1

  assert_equal $(pm_state) "halted_process_failure"
}