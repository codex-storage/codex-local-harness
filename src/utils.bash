#!/usr/bin/env bash

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/config.bash
source "${LIB_SRC}/config.bash"

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