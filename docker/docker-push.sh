#!/usr/bin/env bash

set -eux

docker push deckyfre/catchem-spack-base:0.0.3
docker push deckyfre/catchem-spack-base:latest

docker push deckyfre/catchem:0.0.2
docker push deckyfre/catchem:latest
