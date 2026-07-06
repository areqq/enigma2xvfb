#!/bin/bash
# Start the enigma2-dev container with the plugins directory mounted from the host
set -e
cd "$(dirname "$0")"
podman rm -f enigma2-dev 2>/dev/null || true
exec podman run -d --name enigma2-dev \
    -p 6901:6901 \
    --memory=4g --cpus=4 --pids-limit=1024 \
    -v "$PWD/files/cmdline:/proc/cmdline:ro" \
    -v "$PWD/plugins:/plugins:Z" \
    -v "$PWD/hdd:/media/hdd:Z" \
    -v "$PWD/files/ssl:/certs:Z" \
    $( [ -r /dev/dri/renderD128 ] && [ -w /dev/dri/renderD128 ] && echo --device /dev/dri/renderD128 ) \
    -e VNC_USER="${VNC_USER:-dev}" \
    -e VNC_PW="${VNC_PW:-enigma}" \
    -e GEOMETRY="${GEOMETRY:-1920x1080}" \
    enigma2-dev
