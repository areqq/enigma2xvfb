#!/bin/bash
# Tail the enigma log (the debug log goes to the container stdout)
exec podman logs -f "${1:---tail=200}" enigma2-dev
