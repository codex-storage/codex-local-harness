#!/usr/bin/env bash
LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./src/config.bash
source "${LIB_SRC}/config.bash"
# shellcheck source=./src/utils.bash
source "${LIB_SRC}/utils.bash"

_cdx_output=$(clh_output_folder "codex")
_cdx_logs="${_cdx_output}/logs"
_cdx_data="${_cdx_output}/data"
_cdx_binary="${CLH_CODEX_BINARY:-codex}"

_cdx_base_api_port=8080
_cdx_base_disc_port=8190

cdx_cmdline() {
  local api_port\
    disc_port\
    node_index="$1"\
    cdx_cmd="${_cdx_binary} --nat:none"\
    spr="$2"

  if [[ "$node_index" -gt 0 && -z "$spr" ]]; then
    echoerr "Error: SPR is required for node $node_index"
    return 1
  fi

  api_port=$((_cdx_base_api_port + node_index))
  disc_port=$((_cdx_base_disc_port + node_index))

  echo "${cdx_cmd}"\
" --log-file=${_cdx_output}/logs/codex-${node_index}.log --data-dir=${_cdx_output}/data/codex-${node_index}"\
" --api-port=${api_port} --disc-port=${disc_port} --loglevel=INFO"
}
