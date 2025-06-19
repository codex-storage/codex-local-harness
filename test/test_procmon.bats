setup() {
  load test_helper/common_setup
  common_setup

  source "${LIB_SRC}/procmon.bash"
}

@test "should kill processes recursively" {
  # Note that this is fragile. We need to structure
  # the process tree such that the parent does not exit
  # before the child, or the child will be reparented to
  # init and won't be killed. The defensive thing to do
  # here is to wait on any child you'd like cleaned before
  # exiting its parent subshell.
  (
    # each backgrounded process generates two processes:
    # the process itself, and its subshell.
    sleep 500 &
    sl1=$!
    (
      sleep 500 &
      await $!
    ) &
    sh1=$!
    (
      sleep 500 &
      await $!
    ) &
    sh2=$!
    await $sl1
    await $sh1
    await $sh2
  ) &
  parent=$!

  pm_list_descendants "$parent"
  assert_equal "${#result[@]}" 9

  pm_kill_rec "$parent"
  await "$parent" 5

  pm_list_descendants "$parent"
  # the parent will still show amongst its descendants,
  # even though it is dead.
  assert_equal "${#result[@]}" 1
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

  pm_join 3

  assert_equal $(pm_state) "halted_process_failure"
}

@test "should no longer track a process if requested" {
  assert pm_start

  (
    while true; do
      sleep 1
    done
    pm_job_exit 1
  ) &
  pid1=$!
  pm_track_last_job

  pm_stop_tracking $pid1
  kill -SIGKILL $pid1
  await "$pid1"

  # Again, we need to allow time for the procmon
  # to pick up on the kill.
  sleep 1

  pm_stop
  pm_join 3

  assert_equal $(pm_state) "halted"
}