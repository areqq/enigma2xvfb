#!/bin/bash
# Build the enigma2-dev image (context = parent dir, because of COPY enigma2/)
set -e
cd "$(dirname "$0")/.."
exec podman build -t enigma2-dev -f container/Containerfile "$@" .
