#!/usr/bin/env bash

set -eux

docker buildx build \
  --platform linux/amd64 \
  -t deckyfre/catchem-spack-base-ubuntu-gcc-13-dev:latest \
  -f Dockerfile-Spack-Base \
  --cache-to type=inline \
  --push \
  ..

#docker buildx build \
#  --platform linux/amd64 \
#  -t deckyfre/catchem-spack:0.0.1 \
#  -t deckyfre/catchem-spack:latest \
#  -f Dockerfile-Spack-CATChem \
#  ..

#docker buildx build \
#  --no-cache \
#  --platform linux/amd64 \
#  -t deckyfre/catchem:0.0.4 \
#  -t deckyfre/catchem:latest \
#  -f Dockerfile \
#  ..
