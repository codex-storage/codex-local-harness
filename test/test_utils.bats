#!/usr/bin/env bats
setup() {
  load test_helper/common_setup
  common_setup
}

@test "should shift an array" {
  local arr=(1 2 3)
  shift_arr arr
  assert_equal "${arr[*]}" "2 3"
}

@test "should shift and array by n places" {
  local arr=(1 2 3 4)
  shift_arr arr 2
  assert_equal "${arr[*]}" "3 4"
}