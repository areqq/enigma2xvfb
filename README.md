# Enigma2 (OpenPLi) — containerized development environment

Enigma2 built with the SDL backend (no DVB hardware, boxtype `none`), running
in a podman container behind KasmVNC — a **1920x1080 desktop reachable from any
browser** (tested from macOS). Made for developing and testing enigma2 Python
plugins without a set-top box.

> The historical Xvfb + x11vnc approach lives on the `xvfb` branch.

## Layout

```
.
├── container/          # everything below
│   ├── Containerfile   # two-stage image build (builder + runtime)
│   ├── entrypoint.sh   # KasmVNC + enigma2 restart loop
│   ├── build.sh / run.sh / logs.sh / gui-restart.sh
│   ├── files/          # settings, xstartup, fake /proc/cmdline
│   └── plugins/        # host-mounted dev plugins (HelloWorld example)
└── enigma2/            # OpenPLi enigma2 sources (clone it yourself, gitignored)
```

## Quick start

```bash
git clone https://github.com/OpenPLi/enigma2.git   # sources expected in ./enigma2
./container/build.sh    # image build (first run ~20-30 min)
./container/run.sh      # start the container
./container/logs.sh     # live enigma log (debug level 4)
```

Then open **https://HOST-IP:6901** in a browser
— the certificate is self-signed → accept the warning
— login: `dev`, password: `enigma` (override with `VNC_USER` / `VNC_PW` on `run.sh`)

## Plugin development

- The host directory `container/plugins/` is mounted into the container; every
  subdirectory (e.g. `plugins/HelloWorld/`) is symlinked at startup into
  `/usr/lib/enigma2/python/Plugins/Extensions/<Name>`.
- Edit the code on the host with any editor, then:

```bash
./container/gui-restart.sh   # kills enigma2; the in-container loop restarts the GUI (~10 s)
```

- An enigma crash (e.g. a bug in your plugin) also ends in an automatic
  restart — find the traceback with `./container/logs.sh` and full crash logs
  in `/media/hdd/enigma2_crash_*.log` inside the container.
- A new plugin = a new subdirectory in `plugins/` + a **container** restart
  (`podman restart enigma2-dev`), because symlinks are created by the entrypoint.
- Shell inside the container: `podman exec -it enigma2-dev bash`.

## Environment variables (run.sh)

| Variable   | Default     | Meaning                        |
|------------|-------------|--------------------------------|
| `GEOMETRY` | `1920x1080` | X screen resolution (KasmVNC resizes it to the browser window anyway) |
| `VNC_USER` | `dev`       | KasmVNC login                  |
| `VNC_PW`   | `enigma`    | KasmVNC password               |
| `ENIGMA_DEBUG_LVL` | `4` | enigma debug log level         |

## Keyboard mapping

Keys travel browser → KasmVNC → X → SDL (`lib/driver/rcsdl.cpp`) → remote
control codes → per-screen actions (`data/keymap.xml`). Usable keys:

| PC key | RC button |
|---|---|
| arrows | navigation |
| Enter | OK |
| Esc | EXIT |
| Menu key | MENU (missing on Mac keyboards!) |
| 0–9 | channel number / menu shortcuts |
| F1 / F2 / F3 / F4 | red / **yellow** / **green** / blue (note the F2/F3 order) |
| Help | help screen |
| Home / End | top / bottom of lists |
| Power | standby (careful) |

Not reachable from a keyboard: INFO, EPG, teletext, bouquet +/−, volume +/−.
Keypad arrow keysyms coming out of browsers are remapped back to plain arrows
server-side (see `keyboard.remap_keys` in the entrypoint) — without it enigma
sees digits 2/4/6/8 instead of arrows.

## What is inside the image

- Debian bookworm, Python 3.11
- libdvbsi++ (github.com/oe-alliance/libdvbsi), tuxbox-tuxtxt (github.com/OpenPLi/tuxtxt)
- enigma2 from `./enigma2` (configure: `--with-boxtype=none --with-libsdl=yes`)
- E2-DarkOS FullHD skin (the default for `HasFullHDSkinSupport`)
- a crafted `/usr/lib/enigma.info` (BoxInfo, model `pc`) + `lamedb`
  and `settings` that skip the first-run wizards.
  Note: enigma.info values must be single-quoted (BoxInfo `literal_eval`s
  them) and the About screen hard-requires `imagetype`, `displaydistro`,
  `distro`, `oe` and `kernel` — missing/unquoted values crash enigma with
  SIGKILL via its own bsod handler.
- KasmVNC 1.3.4 (port 6901, https + basic auth).
  The entrypoint generates `~/.vnc/kasmvnc.yaml` which (a) effectively turns
  off brute-force banning — behind podman NAT all clients share one IP and
  auth-less requests (favicon!) count as failed logins, and (b) remaps keypad
  keysyms to arrows.

## After changing enigma C++ code

Rebuild the image (`./container/build.sh` — podman's cache rebuilds only the
enigma layer) and `./container/run.sh` again. Pure Python plugin work needs no
rebuild.

## Troubleshooting

- **Enigma "disappears" for ~10 s** — it crashed and the loop restarted it.
  Check `./container/logs.sh` and `/media/hdd/enigma2_crash_*.log` (a Python
  exception while opening a screen makes enigma kill itself with SIGKILL —
  exit code 137 — by design, via `main/bsod.cpp`).
- **Browser shows `TypeError: ... getScreenPlan`** — the RFB websocket didn't
  connect; historically caused by KasmVNC banning the shared NAT IP (fixed by
  the generated kasmvnc.yaml).
- **Arrows act like digits** — keypad keysym issue, see Keyboard mapping above.
