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

# @test "should keep track of process PIDs" {
#   clh_get_tracked_pids
#   assert [ ${#result[@]} -eq 0 ]

#   (
#     while [ ! -f "${OUTPUT_FOLDER}/stop" ]; do
#       sleep 0.1
#     done
#   ) &
#   clh_track_last_background_job

#   (
#     while [ ! -f "${OUTPUT_FOLDER}/stop" ]; do
#       sleep 0.1
#     done
#   ) &
#   clh_track_last_background_job

#   clh_get_tracked_pids
#   assert [ ${#result[@]} -eq 2 ]

#   touch "${OUTPUT_FOLDER}/stop"

#   clh_get_tracked_pids
#   assert [ ${#result[@]} -eq 0 ]
# }
