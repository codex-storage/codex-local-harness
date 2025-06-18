# FIXME: the Codex we're using is NOT the same as the one in the
#   submodule. Ideally we'd first build the Codex image from
#   that Dockerfile, and then use THAT in here.
FROM codexstorage/nim-codex:latest AS codex

FROM ubuntu:22.04

COPY --from=codex /usr/local/bin/codex /usr/local/bin/codex
ENV CODEX_BINARY=/usr/local/bin/codex

RUN apt-get update && apt-get install -y shellcheck git curl libgomp1

WORKDIR /codex-local-harness
COPY . .

RUN git submodule update --init --recursive




