#!/bin/bash
set -e
set -x

# required directory for enigma2
mkdir -p /dev/input

echo "start Xvfb"
#Xvfb :99 -screen 0 1920x1080x24 -ac -nolisten tcp -noreset &
tigervncpasswd -f <<< 'q' > /root/passwd
chmod 600 /root/passwd
Xvnc :99 -rfbport 5900 -geometry 1920x1080 -depth 24 -Protocol3.3 -localhost no -SecurityTypes VncAuth -PasswordFile /root/passwd
xvfb_pid=$!
echo "exec command $@"
exec "$@"
echo "terminate"
kill ${xvfb_pid}
