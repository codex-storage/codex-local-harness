common_setup() {
  bats_require_minimum_version 1.12.0
  load test_helper/bats-support/load
  load test_helper/bats-assert/load

  export LIB_SRC="${BATS_TEST_DIRNAME}/../src"
  export CODEX_BINARY=${CODEX_BINARY:-"${BATS_TEST_DIRNAME}/codex/build/codex"}

  if [ ! -f "$CODEX_BINARY" ]; then
    echo "Codex binary not found at $CODEX_BINARY"
    exit 1
  fi
}