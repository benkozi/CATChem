#!/usr/bin/env bash

set -eux

docker buildx build \
  --platform linux/amd64 \
  -t deckyfre/catchem-spack-base:0.0.1 \
  -t deckyfre/catchem-spack-base:latest \
  -f Dockerfile-Spack-Base \
  .
