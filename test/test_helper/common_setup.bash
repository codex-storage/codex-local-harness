common_setup() {
  bats_require_minimum_version 1.12.0
  load test_helper/bats-support/load
  load test_helper/bats-assert/load

  LIB_SRC="$(realpath "${BATS_TEST_DIRNAME}/../src")"
  TEST_OUTPUTS="$(realpath "${BATS_TEST_DIRNAME}/../test_outputs")"
  export LIB_SRC TEST_OUTPUTS

  # shellcheck source=./src/utils.bash
  source "${LIB_SRC}/utils.bash"
}

clean_outputs() {
  rm -rf "${TEST_OUTPUTS}"
}