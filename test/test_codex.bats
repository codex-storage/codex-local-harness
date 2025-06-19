#!/usr/bin/env bats

setup() {
  load test_helper/common_setup
  common_setup

  source "${LIB_SRC}/codex.bash"
}

@test "should generate the correct Codex command line for node 0" {
  assert_equal "$(cdx_cmdline 0)" "${_cdx_binary} --nat:none"\
" --log-file=${_cdx_output}/logs/codex-0.log"\
" --data-dir=${_cdx_output}/data/codex-0"\
" --api-port=8080 --disc-port=8190 --log-level=INFO"
}

@test "should generate the correct Codex command line for node 1" {
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
  "${CODEX_BINARY}" --nat:none --data-dir="$data_dir" &> /dev/null &
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

  assert $(! kill -0 "$pid")

  pm_stop
}

@test "should upload and synchronously download file from Codex node" {
  pm_start

  assert cdx_launch_node 0
  assert cdx_ensure_ready 0 3

  filename=$(cdx_generate_file 10)
  cid=$(cdx_upload_file 0 "$filename")

  assert cdx_download_file 0 "$cid"
  assert_equal $(sha1 "${filename}") $(cdx_download_sha1 0 "$cid")

  pm_stop
}

@test "should upload and asynchronously download file from Codex node" {
  pm_start

  assert cdx_launch_node 0
  assert cdx_ensure_ready 0 3

  filename=$(cdx_generate_file 10)
  cid=$(cdx_upload_file 0 "$filename")

  handle=$(cdx_download_file_async 0 "$cid")
  await $handle 3

  assert_equal $(sha1 "${filename}") $(cdx_download_sha1 0 "$cid")

  pm_stop
}

teardown() {
  clh_clear_outputs
}