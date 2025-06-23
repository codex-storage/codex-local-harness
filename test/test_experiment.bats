#!/usr/bin/env bats
# shellcheck disable=SC2128
setup() {
  load test_helper/common_setup
  common_setup

  # shellcheck source=./src/experiment.bash
  source "${LIB_SRC}/experiment.bash"
}

@test "should create experiment folder and set it as the global harness output" {
  output_base="${_clh_output}"

  exp_start "experiment-type"
  experiment_output="${output_base}/experiment-type-[0-9]+-[0-9]+"

  [[ "${_clh_output}" =~ ${experiment_output} ]]

  assert [ -d "${_clh_output}" ]
}

# @test "should add a prometheus target for each Codex node when requested" {
#   pm_start

#   cdx_enable_prometheus "anexperiment" "84858"

#   cdx_launch_node 0
#   config_file="${_prom_output}/8290-anexperiment-84858-node-1-codex.json"
#   assert [ -f "$config_file" ]

#   cdx_destroy_node 0
#   assert [ ! -f "$config_file" ]

#   pm_stop
# }

