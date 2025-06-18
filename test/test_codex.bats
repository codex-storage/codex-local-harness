#!/usr/bin/env bats

setup() {
  load test_helper/common_setup
  common_setup

  source "${LIB_SRC}/codex.bash"
}

@test "should generate the correct Codex command line for node 0" {
  assert_equal "$(cdx_cmdline 0)" "codex --nat:none"\
" --log-file=${_cdx_output}/logs/codex-0.log"\
" --data-dir=${_cdx_output}/data/codex-0"\
" --api-port=8080 --disc-port=8190 --loglevel=INFO"
}

@test "should generate the correct Codex command line for node 1" {
  assert_equal "$(cdx_cmdline 1 'node-spr')" "codex --nat:none"\
" --log-file=${_cdx_output}/logs/codex-1.log"\
" --data-dir=${_cdx_output}/data/codex-1"\
" --api-port=8081 --disc-port=8191 --loglevel=INFO"
}

@test "should refuse to generate the command line for node > 0 if no SPR is provided" {
  assert cdx_cmdline 1 "spr"
  refute cdx_cmdline 1
}