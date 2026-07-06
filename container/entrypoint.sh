#!/bin/bash
# Startup: KasmVNC (as user e2) + an enigma2 loop (restart after every exit/crash).
# NOTE: if you edit this file, bump the revision below — a unique file content
# avoids buildah's blob reuse (a once-poisoned digest stays in storage forever).
# rev: 2026-07-06.10
set -u

VNC_USER="${VNC_USER:-dev}"
VNC_PW="${VNC_PW:-enigma}"
GEOMETRY="${GEOMETRY:-1920x1080}"
export LANG=C.UTF-8 PYTHONUTF8=1

# on a real STB /dev/input is populated by udev; here it just has to exist
mkdir -p /dev/input

# /media/hdd is bind-mounted from the host (container/hdd/) so media and
# enigma crash logs survive container recreation. The host dir belongs to
# the host user (container root); 0777 lets both sides write — enigma (e2)
# drops .cuts/crash logs, the host user manages media files freely.
mkdir -p /media/hdd/movie
chmod 0777 /media/hdd /media/hdd/movie 2>/dev/null || true

# 1) Development plugins: /plugins/<Name> -> Plugins/Extensions/<Name>
EXT=/usr/lib/enigma2/python/Plugins/Extensions
if [ -d /plugins ]; then
    for d in /plugins/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        ln -sfn "${d%/}" "$EXT/$name"
        echo "[entrypoint] plugin linked: $name"
    done
fi

# 2) KasmVNC password
runuser -u e2 -- bash -c \
    "printf '%s\n%s\n' '$VNC_PW' '$VNC_PW' | kasmvncpasswd -u '$VNC_USER' -w" \
    || { echo '[entrypoint] kasmvncpasswd failed'; exit 1; }

# 2b) KasmVNC configuration.
# - Behind podman's NAT every client shares the gateway IP (10.0.2.100) and
#   requests without an auth header (e.g. favicon) count as failed logins,
#   so the default threshold of 5 bans everybody at once.
# - Browser arrow keys may arrive as keypad keysyms (lost E0 prefix /
#   NumLock state) — enigma then sees digits 2/4/6/8; map KP_* keysyms
#   back to their navigation equivalents.
mkdir -p /home/e2/.vnc
cat > /home/e2/.vnc/kasmvnc.yaml <<'YAML'
security:
  brute_force_protection:
    blacklist_threshold: 1000000
    blacklist_timeout: 1
YAML
# persistent TLS cert mounted from the host (container/files/ssl/) — without
# it every image rebuild ships a fresh snakeoil cert and browsers that
# remembered the old one refuse to connect
if [ -r /certs/self.pem ] && [ -r /certs/self.key ]; then
cat >> /home/e2/.vnc/kasmvnc.yaml <<'YAML'
network:
  ssl:
    pem_certificate: /certs/self.pem
    pem_key: /certs/self.key
YAML
fi
cat >> /home/e2/.vnc/kasmvnc.yaml <<'YAML'
keyboard:
  ignore_numlock: true
  remap_keys:
    - 0xff97->0xff52  # KP_Up    -> Up
    - 0xff99->0xff54  # KP_Down  -> Down
    - 0xff96->0xff51  # KP_Left  -> Left
    - 0xff98->0xff53  # KP_Right -> Right
    - 0xff8d->0xff0d  # KP_Enter -> Return
    - 0xff95->0xff50  # KP_Home  -> Home
    - 0xff9c->0xff57  # KP_End   -> End
    - 0xff9a->0xff55  # KP_Prior -> PageUp
    - 0xff9b->0xff56  # KP_Next  -> PageDown
    - 0xffb8->0xff52  # KP_8     -> Up
    - 0xffb2->0xff54  # KP_2     -> Down
    - 0xffb4->0xff51  # KP_4     -> Left
    - 0xffb6->0xff53  # KP_6     -> Right
YAML
chown -R e2:e2 /home/e2/.vnc

# 3) KasmVNC server (X server + web UI on :6901)
runuser -u e2 -- vncserver :1 \
    -geometry "$GEOMETRY" -depth 24 \
    -websocketPort 6901 -interface 0.0.0.0 \
    -select-de manual \
    || { echo '[entrypoint] vncserver failed to start'; cat /home/e2/.vnc/*.log 2>/dev/null; exit 1; }

echo "[entrypoint] KasmVNC is up: https://<host>:6901 (user: $VNC_USER)"

# 3b) Focus keeper: with no window manager the X focus follows the pointer,
# so the unmanaged fullscreen video window (ximagesink) steals the keyboard
# as soon as the mouse rests over it — pin input focus to enigma's SDL
# window (title always ends with "enigma2") so keys keep working.
# (the SDL window has WM_CLASS enigma2 from the start; its WM_NAME is only
# set during playback, so matching by --name would miss it when idle)
runuser -u e2 -- bash -c 'export DISPLAY=:1 XAUTHORITY=/home/e2/.Xauthority
while sleep 2; do
    w=$(xdotool search --limit 1 --class "enigma2" 2>/dev/null | head -1)
    if [ -n "$w" ] && [ "$(xdotool getwindowfocus 2>/dev/null)" != "$w" ]; then
        xdotool windowfocus "$w" 2>/dev/null
    fi
done' &

stop() {
    echo '[entrypoint] shutting down...'
    pkill -TERM enigma2 2>/dev/null
    runuser -u e2 -- vncserver -kill :1 2>/dev/null
    exit 0
}
trap stop TERM INT

# 4) enigma2 loop — logs go to the container's stdout (podman logs -f)
while true; do
    # GST_PLUGIN_FEATURE_RANK: force ximagesink for playbin (servicemp3).
    # autovideosink probing dfbvideosink starts DirectFB's Fusion thread,
    # which segfaults inside the container; GL/wayland sinks are dead ends
    # on Xvnc too. Audio: no audio path in standalone KasmVNC anyway.
    runuser -u e2 -- env HOME=/home/e2 DISPLAY=:1 \
        XAUTHORITY=/home/e2/.Xauthority \
        LANG=C.UTF-8 PYTHONUTF8=1 \
        GST_PLUGIN_FEATURE_RANK="ximagesink:MAX,dfbvideosink:NONE,glimagesink:NONE,gtksink:NONE,gtkwaylandsink:NONE,waylandsink:NONE,kmssink:NONE,fbdevsink:NONE,vah264dec:MAX,vah265dec:MAX,vavp8dec:MAX,vavp9dec:MAX,vaav1dec:MAX,vampeg2dec:MAX" \
        GEOMETRY="$GEOMETRY" \
        ENIGMA_DEBUG_LVL="${ENIGMA_DEBUG_LVL:-4}" \
        /usr/bin/enigma2
    code=$?
    echo "[entrypoint] enigma2 exited with code $code — restarting in 2 s (to stop: podman stop)"
    sleep 2 &
    wait $!
done
