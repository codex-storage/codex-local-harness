common_setup() {
  bats_require_minimum_version 1.12.0
  load test_helper/bats-support/load
  load test_helper/bats-assert/load

  export LIB_SRC="${BATS_TEST_DIRNAME}/../src"
}
