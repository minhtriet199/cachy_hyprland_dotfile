# CachyOS + Hyprland + Isla — handoff for the next AI

Last updated: 2026-10-19. Read this first, then `~/.claude/projects/-home-gamer/memory/cachyos-g14-setup.md`
(longer history). This file explains the machine, the rice ("Isla"), where the code is, the rules the
owner wants followed, and what is still open.

---

## 1. Rules from the owner (follow these)

- **Keep explanations short and simple.** The owner is not a native English speaker; plain words, tables, bullets.
- **Ask before any system change. The owner runs `sudo` themselves** — give them the exact command.
- **Monitor changes: apply live first, never save until confirmed** (rotate/mirror once crashed Hyprland).
  Displays page tries layouts with `screenctl.py poslive` and saves with `pos` only on "Keep".
- **Never symlink Isla files into test folders — copy them** (a test once overwrote shell.qml).
- **After every config change: `dotfiles-sync "short message"`** (commits + pushes). **No Claude credit /
  co-author lines** in dotfiles commits.
- **Isla style rules:** always use `Theme.*` colours (never hard-code; use `Theme.adapt("#hex")` if you must),
  reuse existing components (UiCandy, UiRow, UiText, Glyph, SetSeg, SetToggle…), busy/error messages go inside
  the item they belong to, and every page must fit **both** the upright phone (narrow, < 600 px) and the sideways phone.
- **Lightweight matters.** Prefer events over polling; anything that refreshes repeatedly needs a real reason
  and should slow down while a game is focused (`Services.gaming`).
- Don't open the Isla phone via IPC for screenshots while the owner is typing — it grabs the keyboard.

---

## 2. The machine

| | |
|---|---|
| Laptop | ASUS ROG Zephyrus G14 (GA402RJ), Ryzen 7 6800HS, 16 GB RAM |
| GPU | RX 6700S (card1, drives both screens — MUX "Ultimate") + Radeon 680M iGPU (card0) |
| Screens | ASUS VG27AQ5A **HDMI-A-1** (left, 2560×1440@120, **HDR on**) · laptop **eDP-1** (right, 2560×1600@120, scale 1.25) |
| OS | CachyOS, kernels `linux-cachyos` 7.2.11 and `linux-cachyos-lts` 6.18 (backup) |
| Desktop | **Hyprland 0.56 with the Lua config** (not hyprlang) · login greetd (auto-login) |
| Shell | **Isla** — own Quickshell config (replaced Noctalia, which is no longer started) |
| Input | fcitx5 + bamboo (EN/VI, Ctrl+Shift, `ShareInputState=All`) |
| Bluetooth | MediaTek MT7922 (USB 13d3:3568) — **headset-mode mic is broken** (see §8) |
| Power | asusctl profiles: Quiet=Silent, Balanced=Performance, Performance=Turbo · scx_lavd scheduler (Gaming mode) |

---

## 3. Where everything lives

| What | Path |
|---|---|
| **Dotfiles git repo** | `~/Documents/dot file/` (also reachable as `~/dotfiles`, a link) → github `minhtriet199/cachy_hyprland_dotfile` |
| Sync command | `dotfiles-sync "msg"` (`~/.local/bin/dotfiles-sync` → repo) — rsyncs the configs below into the repo, commits, pushes. Excludes `*.bak*`. |
| Isla repo (original handoff project) | `~/isla-island/` → github `minhtriet199/Cachy-OS-Hyprland-Island` (has its own `isla-sync`) |
| **Isla code** | `~/.config/quickshell/isla/` (≈95 QML files + `tools/`) — run `qs -c isla` |
| Hyprland config | `~/.config/hypr/hyprland.lua` + `config/*.lua` + `scripts/` |
| Saved state | `~/.local/state/isla/prefs.json` (Isla settings) · `~/.local/state/hypr/{look,input,screens,startup}` |
| Old backups | `~/.local/state/isla/old-*-backups-2026-10-19.tar.gz` (all former `.bak` files) |
| Wallpapers | `~/Pictures/Wallpapers` (270 pictures, incl. 266 from Blapples) |
| Snips | `~/Pictures/screenshot` |

The repo also holds `packages-native.txt` / `packages-aur.txt` and `install.sh` for a fresh install.

---

## 4. Hyprland (Lua config)

`hyprland.lua` requires, in order: animations, autostart, startup_isla, colors, decorations, look, variables,
environment, inputs, **input_isla**, binds, **lid**, misc, monitors, windowrules, games, workspaces.

| File | Notes |
|---|---|
| `autostart.lua` | starts `env MALLOC_ARENA_MAX=2 qs -c isla` (≈25 % less RAM), fcitx5, `wl-paste --watch …/isla/tools/clip-store.sh`, boot-lock-guard, `scripts/mic-level.sh` (laptop mic Capture 23 / Boost 0) |
| `startup_isla.lua` | user startup apps from Isla Settings → Apps (`~/.local/state/hypr/startup`) |
| `look.lua` | window opacity / borders / rounding / gaps from Isla Settings → Windows (`scripts/lookctl.py`) |
| `input_isla.lua` | mouse / touchpad / keyboard layout / cursor size (`scripts/inputctl.py`) |
| `lid.lua` | lid switch → `qs ipc call isla lid closed|open` (Isla holds a logind lid inhibitor while running) |
| `binds.lua` | **GENERATED** from `~/.config/hypr/keybinds.json` by `scripts/keybinds.py` — edit the JSON (or Isla → Keyboard), never binds.lua |
| `games.lua` | games open on a new workspace on the launch screen; `follow_mouse=2` while a game is focused |
| `windowrules.lua` | games `immediate` (tearing), terminals/video/password dialogs always opaque |
| `monitors.lua` | driven by `~/.local/state/hypr/screens` (written by `scripts/screenctl.py`) |

Gotchas:
- Live changes: `hyprctl eval 'hl.config({...})'`. `hyprctl dispatch` needs **Lua syntax**, e.g.
  `hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "eDP-1" })'`. Wrong params are silently accepted.
- API stubs: `/usr/share/hypr/stubs/hl.meta.lua`. Integer options (border, rounding, gaps) must be whole numbers.

Key scripts (`~/.config/hypr/scripts/`): `screenctl.py` (screens: list/set/hdr/mode/pos/poslive/order),
`snip.sh` (Super+S: raw-grabs screens first, then freezes — avoids HDR "burnt" snips; puts a corner-jumped
cursor back), `lookctl.py`, `inputctl.py`, `keybinds.py`, `ws.sh` (per-monitor workspaces: ASUS 1–9, laptop 11–19).

---

## 5. Isla — the shell

### Design language
Animal-Crossing-like **"candy sticker"** look: ink outlines, solid drop shadow, white inset shine, soft pastel
gradients, rounded everything, tilted name tags. Fonts bundled in `fonts/`: Fredoka (titles), Nunito (small text),
Titan One (sticker clock). Icons are vector paths in `Glyphs.js` (24×24, use `Glyph { name: "…" }`).

### Structure
- `shell.qml` — windows per screen (bar, dock, drop-downs, phone, toasts, pop-ups) + `IpcHandler` (`qs -c isla ipc call isla <fn>`:
  `phone <screen>`, `close`, `drop <name>`, `bar`, `big`, `power`, `lock`, `locktest` (30 s, safe), `lid`, `preview`).
- `Services.qml` (singleton) — all live data: Hyprland, Wi-Fi/Bluetooth/sound, battery, sysmon, media, notifications,
  clipboard, weather, idle timers, lid, polkit agent, Bluetooth agent, keyring prompter, dark-mode app switching.
- `Prefs.qml` (singleton) — saved settings (`keys` list = what gets saved to prefs.json).
- `Theme.qml` (singleton) — all colours. Colours go through `v(key, default)`, which reads the active **palette**
  (`Prefs.theme`: 5 hand-made + 12 hue-generated + Mono + Custom hue) and applies **dark mode** (`Prefs.dark`, `dk()`).
  `Theme.boxStyle` = candy / ring / pop / soft / flat / glass (drawn in `UiCandy.qml`).
- `PhoneStage.qml` — the 3D "phone" (upright and sideways), screen routing (`allScreens`, `compFor`, kind map).
- Screens: `Scr*.qml` (Home, Quick, Settings grid, Settings pages via `ScrSetPage.qml`, Wallpapers, Clipboard, …).
- Settings pages: `*Panel.qml` loaded by `ScrSetPage.qml` (`kind` → component map). Grid entries in `ScrSettings.qml`,
  search entries in `Services.qml` (`settingsSearch` list).

### Settings pages (01–16)
Wi-Fi · Bluetooth · Sound · Power (incl. lid action) · Shell (Look: theme, Shell/Apps light-dark, box style) ·
Wallpaper · Displays (drag map, any number of screens) · Keyboard (shortcuts, filter chips, clash marker) ·
Screen time · System (charge limit, firewall, SSH, storage, manual update check) · Windows (opacity/borders/gaps,
colour wheel) · Time & language · Mouse & touchpad · Apps (defaults + startup) · Privacy & location · Disk map.

### Helpers in `tools/` (run only when needed)
| Tool | Job |
|---|---|
| `bt-agent.py` | BlueZ pairing agent → `BtPairDialog` (untrusted devices ask Deny / Allow once / Trust) |
| `keyring-prompter.py` | owns `org.gnome.keyring.SystemPrompter`, speaks `org.gnome.keyring.internal.Prompter` → `KeyringDialog` |
| `appearance.py` | apps light/dark: Kvantum Isla↔IslaDark, kdeglobals, GTK isla.css↔isla-dark.css, gsettings |
| `clip-store.sh` | clipboard saver (cliphist + copy times in `~/.cache/isla/cliptimes`) |
| `timelang.py`, `apps.py`, `inuse.py`, `storage.py`, `diskmap.py`, `wifi-info.py`, `setbind.py`, `addbind.py` | data for their pages |

### Look of other apps
- Qt/KDE: Kvantum theme **Isla** (light) / **IslaDark**, qt6ct colours, kdeglobals scheme Isla / IslaDark.
- GTK: `~/.config/gtk-{3,4}.0/isla.css` / `isla-dark.css` imported by `gtk.css`.
- Icons: theme **Isla** (candy folders) inheriting **MacTahoe** → breeze.
- Dolphin: icon view, previews, folder tree (F7) + info panel (F11).
- Helium browser: `~/.config/helium-browser-flags.conf` forces sRGB (fixes washed-out look/snips on the HDR screen).

---

## 6. QML lessons learned the hard way

- **Never put a `//` comment mid-line before more code** — everything after it is silently ignored (once killed a page's scroll/clip).
- **Don't name properties `top`, `left`, `focus`** (FINAL Item properties → "Cannot override FINAL property", whole shell fails to load).
- Inline `component` errors only say "X is not a type" — move it to its own file to see the real error.
- `font.pixelSize` must be an integer. A second `onXChanged:` on the same object = "Property value set multiple times".
- Children of `UiCandy` live in an inner holder, so `parent` is not the delegate — give the delegate an `id`.
- On a load error the **previous config keeps running** — always check `qs -c isla log` after edits.
- Isla does **not** watch prefs.json; to apply an outside edit, change a QML file's *content* (`touch` is ignored).
- PyGObject cannot implement `Gcr.Prompt` (async callback data is lost) — talk D-Bus directly instead.

---

## 7. Performance notes

- Isla ≈ 715 MB RSS with `MALLOC_ARENA_MAX=2` (was ≈ 950 MB). Every Quickshell window has its own GL context; that is the floor.
- Event-based: Hyprland window list (filtered events + 60 s safety), clipboard (file watch), privacy page (PipeWire links), EN/VI (fcitx tray icon).
- Timed: status 4 s (12 s gaming), bar stats 2 s (6 s gaming), weather 30 min.
- While a game is focused: visualizer + spinning record paused, phone light mode, no pop-ups, dock trigger off, mouse focus click-only.
- WARP tray app masked for the user (`systemctl --user unmask warp-taskbar` to undo); WARP itself works from Isla.

---

## 8. Open items / known problems

1. **Baseus Bass BP1 Pro mic doesn't work in Discord (works fine on Windows).**
   - Music (A2DP, "Headphones") works. The mic needs **Headset mode** (HFP, `headset-head-unit`); PipeWire switches to it
     by itself when an app records. Tested both voice codecs (mSBC and CVSD): **0 audio frames**, user log says
     "Failure in Bluetooth audio transport".
   - Root cause on kernel 7.2.9: kernel log `Bluetooth: hci0: SCO packet for unknown connection handle 3584` —
     the MT7922 sends the mic audio, but Linux's `btusb`/`btmtk` driver doesn't recognise the voice channel number
     and drops every packet. Windows uses MediaTek's own driver, which handles it. Not a headset fault.
   - Tried: `btusb enable_autosuspend=n` (`/etc/modprobe.d/btusb.conf`, applied, no help).
   - **2026-10-19 on kernel 7.2.11:** the "unknown connection handle" message is gone, but the transport failure
     still appears (3× this boot) → not fixed yet, needs a real Discord test.
   - **Next steps:** test on 7.2.11 → boot `linux-cachyos-lts` (6.18, installed) and test → if both fail, the fix is a
     USB Bluetooth dongle (Intel/Realtek) for the headset. Workaround now: laptop mic in Discord, Baseus as speaker.
   - Isla's Bluetooth row shows 🎧 Headphones / 🎙 Headset (headset icon with mic) and tapping the icon switches mode.
   - **2026-10-19 later:** on 7.2.11 kernel now logs `Bluetooth: hci0: corrupted SCO packet` + transport failure → still broken.
   - **LTS 6.18 tested too (2026-10-19):** mSBC and CVSD both record silence; kernel logs "SCO packet for unknown
     connection handle 3584" + "corrupted SCO packet". Both kernels fail → USB Bluetooth dongle is the fix.
   - **Laptop mic (corrected 2026-10-19):** the real mic is the Realtek ALC285 "Internal Mic" (HDA, hw:Generic_1).
     It was just far too loud: Capture 63 (+30 dB) + Internal Mic Boost (+20/30 dB) → clipped noise. At Capture 23 (0 dB),
     Boost 0 it records clean. **Confirmed:** Discord's Automatic Gain Control pushed it back to 63 + Boost 2 within
     seconds → owner turned AGC off in Discord (app + web). `~/.config/hypr/scripts/mic-level.sh` (run at login from
     autostart.lua) sets Capture 23 / Boost 0.
   - **"Laptop Mic (clear)" (`mic_clean`) — DEFAULT mic since 2026-10-19:** PipeWire filter-chain in
     `~/.config/pipewire/pipewire.conf.d/60-mic-clean.conf`: 2× high-pass 140 Hz (owner said bass/boom too strong),
     −4 dB @ 300 Hz, +3 dB @ 3.5 kHz, mono. Passive → sleeps (0 CPU) unless an app records; ~0.1 % CPU, no gaming impact.
     Apps' AGC on it only changes its software volume, not the hardware gain. Tune Freq/Gain there if the owner asks
     (more bass cut → 180–200 Hz), then `systemctl --user restart pipewire pipewire-pulse wireplumber`.
     The ACP digital mic (acp6x) is NOT wired on GA402RJ: a patched driver (`~/.local/src/acp6x-ga402r/`, test only,
     never installed) made the card appear but it records only stuck samples. Loading it also switches the HDA card
     to a UCM "HiFi" profile where WirePlumber picks the dead DMIC as default — don't install it.
   - WirePlumber `bluetooth.autoswitch-to-headset-profile` set to **false** (saved) so apps don't flip the Baseus into
     the broken headset mode or make its mic the default.
2. **Game mode switch** in Shell settings does nothing (original Isla bug). Owner was asked whether it should switch
   to Turbo/Performance + disable blur/animations while gaming — no answer yet.
3. **SekaiPop-style widgets** (weather/calendar/palette/profile cards): owner was asked A (restyle cards) / B (+palette
   from wallpaper) / C (desktop widgets) — no answer yet.
4. Not verified on screen yet: power-menu countdown, wallpaper Preview, lock-screen eye button, clipboard copy times after reboot.
5. Leftover `.pacnew` files in /etc (pacman.conf, resolv.conf, mirrorlists) are old/plain-Arch — **keep the current files**.
6. Owner declined keyring auto-unlock — don't add it.

---

## 9. Quick commands

```sh
qs -c isla log                 # Isla log (errors after edits)
qs -c isla kill; qs -c isla -d # restart Isla
qs -c isla ipc call isla phone settingsQuick   # open a phone page
hyprctl configerrors           # Hyprland config errors
dotfiles-sync "message"        # commit + push configs
```
