#!/usr/bin/env bash

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./config.bash
source "${LIB_SRC}/config.bash"

clh_output_folder() {
  echo "${OUTPUTS}/$1"
}

echoerr() {
  echo "$@" >&2
}

await() {
  local pid=$1
  while kill -0 "$pid"; do
    sleep 0.1
  done
}