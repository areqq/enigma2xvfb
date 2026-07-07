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
- The host directory `container/hdd/` is mounted as `/media/hdd` — drop media
  files into `container/hdd/movie/` on the host and they are instantly visible
  to enigma; enigma's crash logs (`enigma2_crash_*.log`) land there too and
  survive container recreation.
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
control codes → per-screen actions (`data/keymap.xml`). The bundled
**MacKeymap** dev plugin (`container/plugins/MacKeymap/keymap.xml`) adds global
key *translations* for the SDL input device, so a plain Mac(Book) keyboard can
reach every remote-control button — including the keys used by
AdvancedFreePlayer. Translations never affect text fields (those switch the
input to ASCII mode which bypasses translation).

**Caveat:** some screens — notably Channel Selection, the very first thing you
see — turn on quick-search-by-typing for their whole duration. While that's
active, *every* printable key (all letters, digits, most punctuation) is
delivered as literal text instead of a remote-control code, so the
letter/punctuation aliases below are silently ignored there. Only F1–F12,
arrows, Enter/Esc/Tab/Backspace, Home/End/PageUp/PageDown/Insert/Delete and
the keypad survive quick-search unaffected — that's why F5–F12 duplicate the
essential letters. When in doubt about the current screen, reach for an
F-key.

Native keys (no translation needed):

| Key | RC button |
|---|---|
| arrows | navigation |
| Enter | OK |
| Esc | EXIT |
| 0–9 | digits (channel number, menu shortcuts, AFP time jumps) |
| PageUp / PageDown (Fn+↑/↓ on a Mac) | page up/down, AFP subtitle seek |
| Home (Fn+← on a Mac) | AFP exit player |
| Power | standby (careful) |

MacKeymap letter/symbol aliases:

| Key | RC button | Typical use |
|---|---|---|
| M | MENU | main/context menu |
| I | INFO | infobar, AFP infobar toggle |
| E | EPG | programme guide |
| H | HELP | help / AFP help screen |
| O | OK | OK (also in AFP contexts) |
| A | AUDIO | audio track selection |
| S | SUBTITLE | subtitle menu |
| T | TEXT | teletext / AFP subtitle selection |
| C | TV | AFP subtitle toggle (KEY_TV) |
| V | VIDEO | movie list |
| R / G / Y / B | RED / GREEN / YELLOW / BLUE | color buttons |
| F1 / F2 / F3 / F4 | RED / GREEN / YELLOW / BLUE | color buttons (alt path) |
| F5 / F6 / F7 / F8 | MENU / INFO / EPG / HELP | quick-search-proof alt path |
| F9 / F10 / F11 / F12 | AUDIO / SUBTITLE / TEXT / TV | quick-search-proof alt path |
| P | PLAY | AFP play (selector) / pause toggle (player) |
| Space | PLAY/PAUSE | pause toggle |
| X | STOP | stop / AFP exit |
| , / . | REWIND / FASTFORWARD | seeking |
| = / - | CHANNEL +/− | bouquet, AFP subtitle time shift |
| ] / [ | VOLUME +/− | volume |
| \ | MUTE | mute |

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
- GStreamer 1.x (base/good/bad/libav) + OpenPLi **servicemp3** built against
  the enigma2 headers — media playback via service type 4097 (the default of
  e.g. AdvancedFreePlayer). Video rendering on a PC build is experimental:
  playbin autoplugs an X video sink into a window on the same display.
  **No audio in the browser** — standalone KasmVNC has no audio channel.
  **Known limitation:** that video window is a separate, un-composited X11
  window that fully covers enigma's own canvas while playing — any OSD
  enigma draws on top of video (subtitles, whether via the native subtitle
  track menu or a plugin's own overlay like AFP's, the info bar, pop-up
  dialogs) is therefore invisible, not just subtitles specifically. A
  fix needs real compositing (an alpha-aware canvas + a compositing WM, or
  embedding the video into a window enigma actually manages) — out of
  scope for a quick patch; a naive "shrink the video window" attempt
  broke GStreamer's scaling math instead of helping, so it wasn't kept.

## Third-party plugins

Drop any enigma2 plugin directory into `container/plugins/` and restart the
container. Example — J00zek's AdvancedFreePlayer (not committed to this repo;
it is third-party code):

```bash
curl -sL -o /tmp/afp.ipk 'https://github.com/j00zek/eeRepo/raw/main/enigma2-plugin-extensions--j00zeks-advancedfreeplayer_25.11.26.1210_all.ipk'
cd /tmp && ar x afp.ipk data.tar.gz && tar xzf data.tar.gz
cp -r /tmp/usr/lib/enigma2/python/Plugins/Extensions/AdvancedFreePlayer container/plugins/
podman restart enigma2-dev
```

Every key AFP listens for is covered by the MacKeymap table above.

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
- **Letters/menu don't seem to do anything** — you're probably on a
  quick-search-enabled screen (e.g. Channel Selection); use an F-key
  instead, see the Keyboard mapping caveat above.
- **Stuck on a frozen video frame, nothing responds** — a dialog (e.g. "Exit
  movie player?", a delete-file confirmation) is open but hidden behind the
  video window (see the window-stacking limitation above). The keyboard
  still reaches it: Enter/Escape blindly often gets you out. If not,
  `./container/gui-restart.sh` recovers cleanly (enigma restarts in ~10 s).
