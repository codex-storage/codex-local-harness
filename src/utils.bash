#!/usr/bin/env bash
set -o pipefail

if ! command -v sha1sum > /dev/null; then
  echoerr "Error: sha1sum is required for computing file hashes"
  exit 1
fi

clh_init() {
  _clh_output=${1:-$(mktemp -d)} || exit 1
  _clh_output=$(realpath "$_clh_output") || exit 1
  mkdir -p "${_clh_output}" || exit 1
  export _clh_output
}

clh_output_folder() {
  echo "${_clh_output}/$1"
}

clh_destroy() {
  rm -rf "${_clh_output}" || true
}

echoerr() {
  echo "$@" >&2
}

sha1() {
  sha1sum "$1" | cut -d ' ' -f 1 || return 1
}