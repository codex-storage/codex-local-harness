#!/usr/bin/env bats
# shellcheck disable=SC2128
setup() {
  load test_helper/common_setup
  common_setup

  # shellcheck source=./src/codex.bash
  source "${LIB_SRC}/codex.bash"
}

@test "should generate the correct Codex command line for node 0" {
  # shellcheck disable=SC2140
  assert_equal "$(cdx_cmdline 0)" "${_cdx_binary} --nat:none"\
" --log-file=${_cdx_output}/logs/codex-0.log"\
" --data-dir=${_cdx_output}/data/codex-0"\
" --api-port=8080 --disc-port=8190 --log-level=INFO"
}

@test "should generate the correct Codex command line for node 1" {
  # shellcheck disable=SC2140
  assert_equal "$(cdx_cmdline 1 '--bootstrap-node' 'node-spr')" "${_cdx_binary} --nat:none"\
" --bootstrap-node=node-spr --log-file=${_cdx_output}/logs/codex-1.log"\
" --data-dir=${_cdx_output}/data/codex-1"\
" --api-port=8081 --disc-port=8191 --log-level=INFO"
}

@test "should refuse to generate the command line for node > 0 if no SPR is provided" {
  assert cdx_cmdline 1 "--bootstrap-node" "spr"
  refute cdx_cmdline 1
}

@test "should generate metrics options when metrics enabled for node" {
  # shellcheck disable=SC2140
  assert_equal "$(cdx_cmdline 0 --metrics)" "${_cdx_binary} --nat:none"\
" --metrics --metrics-port=8290 --metrics-address=0.0.0.0"\
" --log-file=${_cdx_output}/logs/codex-0.log"\
" --data-dir=${_cdx_output}/data/codex-0"\
" --api-port=8080 --disc-port=8190 --log-level=INFO"
}

@test "should fail readiness check if node is not running" {
  refute cdx_ensure_ready 0 1
}

@test "should pass readiness check if node is running" {
  data_dir=$(clh_output_folder "codex-temp")
  "${_cdx_binary}" --nat:none --data-dir="$data_dir" &> /dev/null &
  pid=$!

  assert cdx_ensure_ready 0 3

  kill -SIGKILL "$pid"
  await "$pid"
  rm -rf "$data_dir"
}

@test "should launch a Codex node" {
  pm_start

  assert cdx_launch_node 0
  assert cdx_ensure_ready 0 3

  # We should see a log file and a data directory.
  assert [ -f "${_cdx_output}/logs/codex-0.log" ]
  assert [ -d "${_cdx_output}/data/codex-0" ]

  pid="${_cdx_pids[0]}"
  assert [ -n "$pid" ]

  cdx_destroy_node 0 true

  refute [ -d "${_cdx_output}/data/codex-0" ]
  refute [ -f "${_cdx_output}/logs/codex-0.log" ]
  assert [ -z "${_cdx_pids[0]}" ]

  # Node should already be dead.
  refute kill -0 "$pid"

  pm_stop
}

@test "should check downloaded content" {
  mkdir -p "${_cdx_genfiles}"
  mkdir -p "${_cdx_uploads}/codex-0"
  mkdir -p "${_cdx_downloads}/codex-1"

  filename=$(cdx_generate_file 10)

  sha1 "$filename" > "${_cdx_uploads}/codex-0/fakecid.sha1"
  cp "$filename" "${_cdx_downloads}/codex-1/fakecid"

  # Checks that the file uploaded at 0 matches the file downloaded at 1.
  assert cdx_check_download 0 1 "fakecid"
}

@test "should upload and synchronously download file from Codex node" {
  pm_start

  assert cdx_launch_node 0
  assert cdx_ensure_ready 0 3

  filename=$(cdx_generate_file 10)
  cid=$(cdx_upload_file 0 "$filename")

  assert cdx_download_file 0 "$cid"

  assert cdx_check_download 0 0 "$cid"

  pm_stop
}

@test "should upload and asynchronously download file from Codex node" {
  pm_start

  assert cdx_launch_node 0
  assert cdx_ensure_ready 0 3

  filename=$(cdx_generate_file 10)
  cid=$(cdx_upload_file 0 "$filename")

  cdx_download_file_async 0 "$cid"
  handle=$result

  await "$handle" 3

  assert cdx_check_download 0 0 "$cid"

  pm_stop
}

@test "should launch a Codex network and allow uploading and downloading" {
  pm_start

  assert cdx_launch_network 5

  filename=$(cdx_generate_file 10)
  cid=$(cdx_upload_file 0 "$filename")

  handles=()
  for i in {1..4}; do
    cdx_download_file_async "$i" "$cid"
    handles+=("$result")
  done

  assert await_all "${handles[@]}"

  for i in {1..4}; do
    assert cdx_check_download 0 "$i" "$cid"
  done

  pm_stop
}

@test "should log download timing information when requested" {
  pm_start

  cdx_log_timings_start "${_cdx_output}/experiment-0.csv" "experiment-0,100MB"

  assert cdx_launch_network 5

  filename=$(cdx_generate_file 10)
  cid=$(cdx_upload_file 0 "$filename")

  handles=()
  for i in {1..4}; do
    cdx_download_file_async "$i" "$cid"
    handles+=("$result")
  done

  assert await_all "${handles[@]}"

  for i in {1..4}; do
    assert cdx_check_download 0 "$i" "$cid"
  done

  cdx_log_timings_end
  pm_stop

  assert [ -f "${_cdx_output}/experiment-0.csv" ]
  assert [ "$(<"${_cdx_output}/experiment-0.csv" wc -l)" -eq 4 ]

  decimal_regex='^[0-9]+(\.[0-9]+)?$'

  while IFS=',' read -r experiment file_size operation node_index recorded_cid wallclock user system; do
    assert [ "$experiment" = "experiment-0" ]
    assert [ "$file_size" = "100MB" ]
    assert [ "$recorded_cid" = "$cid" ]
    assert [ "$operation" = "download" ]

    # We can't use asserts for regex matches so use "raw" bats
    # assertions.
    [[ "$node_index" =~ [1-4] ]]
    [[ "$wallclock" =~ $decimal_regex ]]
    [[ "$user" =~ $decimal_regex ]]
    [[ "$system" =~ $decimal_regex ]]
  done < "${_cdx_output}/experiment-0.csv"
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

teardown() {
  clh_clear_outputs
}
