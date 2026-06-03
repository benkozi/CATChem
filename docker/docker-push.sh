#!/usr/bin/env bash

set -eux

docker push deckyfre/catchem-spack-base:0.0.4
docker push deckyfre/catchem-spack-base:latest

docker push deckyfre/catchem:0.0.4
docker push deckyfre/catchem:latest
