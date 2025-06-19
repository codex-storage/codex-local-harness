#!/usr/bin/env bash
set -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/config.bash
source "${LIB_SRC}/config.bash"

if ! command -v sha1sum > /dev/null; then
  echoerr "Error: sha1sum is required for computing file hashes"
  exit 1
fi

OUTPUTS=${OUTPUTS:-$(mktemp -d)} || exit 1
OUTPUTS=$(realpath "$OUTPUTS") || exit 1

clh_output_folder() {
  echo "${OUTPUTS}/$1"
}

echoerr() {
  echo "$@" >&2
}

await() {
  local pid=$1 timeout=${2:-30} start="${SECONDS}"
  while kill -0 "$pid"; do
    if ((SECONDS - start > timeout)); then
      echoerr "Error: timeout waiting for process $pid to exit"
      return 1
    fi
    sleep 0.1
  done
  return 0
}

sha1() {
  sha1sum "$1" | cut -d ' ' -f 1 || return 1
}