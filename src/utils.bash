#!/usr/bin/env bash
set -o pipefail

if ! command -v sha1sum > /dev/null; then
  echoerr "Error: sha1sum is required for computing file hashes"
  exit 1
fi

echoerr() {
  echo "$@" >&2
}

shift_arr () {
  local -n arr_ref="$1"
  local shifts="${2:-1}"
  arr_ref=("${arr_ref[@]:shifts}")
}

sha1() {
  sha1sum "$1" | cut -d ' ' -f 1 || return 1
}