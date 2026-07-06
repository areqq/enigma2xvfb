#!/bin/bash
# Restart the enigma GUI (reloads Python code / plugins) without restarting the container
exec podman exec enigma2-dev pkill -f /usr/bin/enigma2
