#!/usr/bin/env bash
set -e -o pipefail

if [ "$OSTYPE" = "darwin" ]; then
  HOST_IP="host-gateway"
elif [ "$OSTYPE" = "linux-gnu" ]; then
  HOST_IP=$(hostname -I | cut -d " " -f 1)
else
  echo "Unsupported OS: $OSTYPE"
  exit 1
fi

export HOST_IP
docker compose up "$@"
