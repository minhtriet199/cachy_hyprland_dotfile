# CachyOS + Hyprland + Island — handoff for the next AI

Last updated: 2026-10-22. Read this first. Longer history: memory `cachyos-g14-setup.md` and the full old copy of
this file at `~/.local/state/island/RICE-HANDOFF-full-2026-10-22.md`.

---

## 1. Owner rules (follow these)

- **Short, simple explanations.** The owner is not a native English speaker: plain words, tables, bullets.
- **Ask before any system change. The owner runs `sudo` themselves**: give them the exact command.
- **Monitor changes: apply live first, never save until confirmed** (rotate/mirror once crashed Hyprland).
- **After every config change: `dotfiles-sync "short message"`**. No Claude credit / co-author lines there.
- **Test in a separate nested desktop, never on the main one** (owner likes this, see §2). Don't open the real phone
  by IPC while the owner may be typing: it grabs the keyboard.
- **Never symlink Island files into test folders. Copy them** (a test once overwrote shell.qml).
- **After any change, recheck old features too**, not just the new one. Say plainly what was and wasn't checked.
- **Island style:** `Theme.*` colours only (`Theme.adapt("#hex")` if you must), reuse components (UiCandy, UiRow, UiText,
  Glyph, SetSeg, SetToggle…), busy/error text inside the item it belongs to, every page fits **both** the upright
  phone (< 600 px wide) and the sideways phone.

### Principles
1. **Clean, small code.** One shared piece, not variants (`DropCard`, `UiRow`, `Theme.tilt(i)`, `Svc*.qml` parts).
   Delete the old version when replacing it. Match the comments/naming around you.
2. **Performance is measured, not guessed.** Before/after RSS of `qs -c island`. Prefer events over timers; polls use bash
   `read` builtins; slow down while gaming / Game mode (`Services.calm`).
3. **Lazy where it pays.** The phone is built on first open, removed 3 min after closing. Small windows stay
   (measured: not worth it).
4. **SekaiPop design** (§5): dense, small tilts, sticker shadows, dark tiles mixed with light ones.

---

## 2. How to test (nested Hyprland — owner's preferred way)

A second Hyprland runs as a window on the desktop, with a **scratch copy** of Island inside it. The real desktop and
real settings are not touched.

1. Copy: `cp -r ~/.config/quickshell/island $T/island; mkdir $T/state; cp ~/.local/state/island/prefs.json $T/state/`
2. Patch the **copy**: `Prefs.qml` `dir` → `$T/state` (so it never writes the real prefs.json); in `Services.qml` turn
   off `agents` (running: false), remove `PolkitAgent`, the 3 idle `IdleMonitor`s (`enabled: false &&`), the lid
   `systemd-inhibit` process and the screen-time 5 s timer. Add a test IPC function to `shell.qml` if you need to
   poke state (e.g. set `Services.wallPreview`, `Prefs.phoneWindow`).
3. Config `$T/nest.lua`: `hl.monitor({ output = "WAYLAND-1", mode = "1920x1080", position = "0x0", scale = 1 })`, the
   window rules you are testing, and `hl.on("hyprland.start", function () hl.exec_cmd("qs -p $T/island > $T/qs.log 2>&1") end)`.
   Check with `Hyprland --verify-config -c $T/nest.lua`.
4. Run (in the background): `dbus-run-session Hyprland -c $T/nest.lua`
5. Run commands inside it with `HYPRLAND_INSTANCE_SIGNATURE` + `WAYLAND_DISPLAY` of the newest `hyprctl instances`
   entry: `qs -p $T/island ipc call island …`, `hyprctl clients`, `grim` (screenshots), and
   `hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "CTRL", key = "S", window = "title:^(…)$" })'` for key presses.
6. Check `$T/qs.log`. Stop with `hyprctl dispatch 'hl.dsp.exit()'` (inside the nested one).
- The nested window's size can change between shots: crop by window geometry (`grim -g`), not fixed numbers.
- Then restart the real Island fresh (§7) and check its log + `hyprctl configerrors`.

---

## 3. The machine

| | |
|---|---|
| Laptop | ASUS ROG Zephyrus G14 (GA402RJ), Ryzen 7 6800HS, 16 GB RAM |
| GPU | RX 6700S (card1, drives both screens — MUX "Ultimate") + Radeon 680M (card0) |
| Screens | ASUS VG27AQ5A **HDMI-A-1** (left, 2560×1440@120, **HDR on**) · laptop **eDP-1** (right, 2560×1600@120, scale 1.25) |
| OS | CachyOS, kernels `linux-cachyos` 7.2.11 + `linux-cachyos-lts` 6.18 (backup) |
| Desktop | **Hyprland 0.56, Lua config** · login: greetd + **island-greeter** (`install.sh autologin` = boot into locked session, see island-greeter README) |
| Shell | **Island**, own Quickshell config (`qs -c island`) |
| Input | fcitx5 + bamboo (EN/VI, Ctrl+Shift) |
| Bluetooth | MediaTek MT7922 — **headset-mode mic broken** (§8) |
| Power | asusctl Quiet=Silent, Balanced=Performance, Performance=Turbo · scx_lavd |

---

## 4. Where things live

| What | Path |
|---|---|
| Dotfiles repo | `~/Documents/dot file/` (= `~/dotfiles`) → github `minhtriet199/cachy_hyprland_dotfile`. Also `packages-*.txt` + `install.sh` |
| Sync | `dotfiles-sync "msg"` — rsync configs into the repo, commit, push (skips `*.bak*`) |
| Island code | `~/.config/quickshell/island/` (≈ 95 QML files + `tools/`) |
| Hyprland | `~/.config/hypr/hyprland.lua` + `config/*.lua` + `scripts/` |
| State | `~/.local/state/island/prefs.json` · `~/.local/state/hypr/{look,input,screens,startup,gamemode}` |
| Backups | `~/.local/state/island/*.tar.gz` |
| Wallpapers / snips | `~/Pictures/Wallpapers` · `~/Pictures/screenshot` |

### Hyprland notes
- `binds.lua` is **generated** from `keybinds.json` by `scripts/keybinds.py generate`. Edit the JSON, never binds.lua.
- `look.lua` / `input_island.lua` / `monitors.lua` / `startup_island.lua` are driven by Island settings (`lookctl.py`,
  `inputctl.py`, `screenctl.py`).
- `games.lua`: games open on a new workspace; `follow_mouse=2` while a game is focused. `workspaces.lua`: 1–9 on the first
  non-eDP screen, laptop 11–19. Island `Services.rehome()` moves windows when a screen is unplugged.
- `windowrules.lua`: games `immediate`; every window follows focus/unfocus opacity (no "always solid" rules);
  PiP floats + `no_initial_focus`; "Island Phone" window: float, no border/shadow/blur.
- Live changes: `hyprctl eval 'hl.config({...})'`. `hyprctl dispatch` needs **Lua**:
  `hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "eDP-1" })'`. Wrong params are accepted silently.
  API: `/usr/share/hypr/stubs/hl.meta.lua`. Integer options must be whole numbers.
- Key scripts: `screenctl.py`, `snip.sh` (Print/Super+S), `pip-toggle.sh` (Super+Q), `lookctl.py`, `keybinds.py`, `ws.sh`.

---

## 5. Island

### Structure
- `shell.qml` — per-screen windows (bar, dock, dropdowns, phone, toasts, pop-ups) + `IpcHandler`
  (`qs -c island ipc call island <fn>`: `phone <screen>`, `close`, `phonemode`, `rotate`, `big`, `drop <name>`, `bar`, `power`,
  `lock`, `locktest` (30 s, safe), `lid`, `preview`, `gamemode`, `palette …`, `snip`, `locate`, `sharePick`).
- `Services.qml` — all live data (stats in `SvcSysmon`, weather `SvcWeather`, colours `SvcPalette`, calendar `SvcSchedule`,
  recording `SvcRecord`). Settings search list = `settingsSearch`.
- `Prefs.qml` — saved settings (`keys` list = what's saved). `Theme.qml` — colours via palette + dark mode; box styles in `UiCandy`.
- `PhoneStage.qml` — the 3D phone (upright + sideways), page routing (`allScreens`, `compFor`). Both phones turn together;
  `portShown`/`landShown` = what each shows. Pages: `Scr*.qml`; settings pages `*Panel.qml` via `ScrSetPage.qml`.

### Phone features
| Feature | How |
|---|---|
| Keys | Ctrl+S turn · Ctrl+F big/small · Ctrl+1…5 jump · Ctrl+←/→ page ↔ buttons · Alt+←/Backspace back · F1 help · Esc close |
| **Phone as a window** | Settings → Look → **Open as: Overlay / Window** (`Prefs.phoneWindow`), or **Super+Z** (`ipc phonemode`). **One phone moves:** overlay → window = the overlay phone glides to the window's spot (screen's free-area middle) at the window phone's size while the window opens hidden (`phoneGhost`), is resized/moved exactly there, shown, then the overlay `vanish()`es; window → overlay = overlay `takeOver()`s on top of the window phone (from `hyprctl clients`), the window vanishes, the phone glides home (`handT`, `handAim` in PhoneStage; `swapGo`/`swapStep` in shell.qml). Pixel-checked: same spot + size. One `FloatingWindow` "Island Phone" in shell.qml, lazy like the overlay; transparent, hugs the phone. `PhoneStage { windowed: true }` = flat big pose, no scrim, no big button. Hyprland ignores client resizes, so a turn sends `hl.dsp.window.resize` (stays centred). |
| **Wallpaper live preview** | 👁 Preview / Space → phone shrinks to the bottom-right corner (`cornerScale`/`cornerMove`), page shows only the string + buttons, desktop follows the picked picture 220 ms after it settles. Esc / Space / ✕ / click outside ends it. Known: upright and sideways pages keep their own position, so turning mid-preview can jump. |
| Phone height | Settings → Look → Phone: Low / Middle / High (`Prefs.phoneSpot`) |
| Calculator | `ScrCalc.qml`: operators in a row → the new one wins (× − stays: negative), `tidy()` drops a dangling operator, closes brackets, 2(3) = 2×3; after = a digit starts fresh, an operator goes on, = again repeats the last step; ÷ 0 → ERROR. Maths = `Services.math` (shared with search). |

### Other built features
| Feature | Files / notes |
|---|---|
| Snip editor | `hypr/scripts/snip.sh` + `SnipEditor.qml`. Enter/Save = file + copy, Esc/click outside = copy only. Resize handles, Select tool. Window id `sn` (never `ed`, see §6). |
| Record → OBS | `tools/obsctl.py`, `share-pick.sh`, `SharePicker.qml`, `SvcRecord.qml`, `hypr/xdph.conf`. See memory `obs-record-flow`. XDPH window addresses are decimal, Hyprland's hex. |
| Calendar notes + reminders | `SvcSchedule.qml`, `DropCalendar.qml`; data `~/.local/state/island/schedule.json`. Held during Do not disturb. |
| Clipboard | pins in `Prefs.clipPins` + `~/.local/share/island/clip-pins/`; `tools/clip-prune.sh` deletes unpinned items older than `Prefs.clipDays`. Quick saves: Super+C → `tools/clip-hide.sh` (silent; presses copy in the app, restores the old clipboard — primary selection is off) → files in dot-folder `~/.local/share/island/.k` (not synced); Ctrl ×3 on the Super+V clipboard toggles screen `clipHidden`; copied back with `wl-copy --sensitive` so cliphist skips it. |
| GRUB theme | Evangelion (Aleph1-9012, Apache-2.0) in `/usr/local/share/evangelion`, CLI `sudo eva` (set/list/status/rollback/uninstall). Active: Soryu 1440p, gfxmode 2560x1600 (block in /etc/default/grub). Copy in dotfiles `system/usr/local/share/evangelion`; install.sh re-applies it. |
| To-do | Bar ✓ → `DropTodo.qml` (card) + `TodoBoard.qml` (shared board; big window "Island Todo" at k 1.6) + `SvcTodo.qml` (Services.todo). Boards = Markdown in `~/Documents/Todo/<name>.md` (`- [ ] text`, files as indented `- [name](<path>)`). Prefs.todoLast. Opening a file pins the card (drop window input mask = card only) until the window that opened closes (Hyprland openwindow/closewindow). Ctrl+click = `dolphin --select`. Video thumbs: ffmpegthumbnailer → ~/.cache/island/todo-thumbs. |
| Recovery | Settings 17 → `tools/snapshot.py` (list/create/restore/delete): tar.gz snapshots of Island, greeter sources, ~/.config/hypr, themes, prefs in `~/.local/state/island-snapshots` (not synced). Restore runs detached, saves an automatic "Before restoring…" snapshot first (newest 10 automatic kept), then `qs kill` → extract → `hyprctl reload` → start Island. |
| Brightness per screen | `DropBattery.qml` (DDC or HDR nits) |
| Double-tap Ctrl rings | `hypr/config/locate.lua` → `ipc locate X Y` → `LocatePointer.qml` |
| Game mode | Settings → Quick or `ipc gamemode`: animations off, phone light mode, visualizer paused |
| Apps look | Kvantum Island/IslandDark, qt6ct, GTK `island.css`/`island-dark.css`, icons Island → MacTahoe. Helium forced sRGB (HDR). |

### Card design (SekaiPop — github.com/Blapples/SekaiPop, refs `~/Pictures/screenshot/sekaipop-reference/`)
- Every bar dropdown is a `DropCard` with one header style (inset box in `Theme.gActive[0]`, halftone dots); content ≥ 22 px from the edge.
- Dense, a bit cramped; small tilts `Theme.tilt(i)`; sticker shadows (`drop: 3`); dark ink tiles mixed with light; pills over the header edge.
- Weather card: only condition, temp, high/low, place, humidity · wind · UV, 8-point hourly line.
- Palette button in the bar → `PaletteCard` (+ `ipc palette get|wallpaper|music|random|shuffle|apply|undo`).
- Transition colour "Wallpaper": `SvcPalette` keeps `Prefs.wipeAuto` fresh (greeter needs `sudo …/island-greeter/install.sh` to follow).

### Lock / login (one `LockScreen.qml` for both, 2026-10-22)
- Rest = lock wallpaper (or sky) + date + big sticker clock + "Press any key". Any key/click → `PhoneBody` slides up
  (810 of 1080 design px), only the background Item is blurred (`MultiEffect` on a layer, so the desktop never shows).
  Phone: avatar/name, "Locked since" / "Welcome back", user pick (greeter, >1 user), password dots, Unlock/Log in,
  song (lock), Restart/Shut down (4 s countdown, other button = Cancel). Esc: cancel → clear → hide. 30 s idle → hides.
- Shared state in the lock controller (`lockCtl` in island/shell.qml and island-greeter/shell.qml): `phoneUp`, `user`.
  Success (`leaving`): phone is pulled down off screen (InBack, blur + hidden clock stay) → iris cover → desktop. `PhoneBody { canBig: false }` on the lock.
- Boot colour hand-over: Island `Prefs` writes `~/.local/state/hypr/cover` (wipe colour); `misc.lua` and greeter.lua
  use it as Hyprland's background; Prefs loads with `blockLoading` so Island's first frame already has it.
- Gap between greeter Hyprland and your session = VT1 text console. logind resets it to black when the greeter session
  closes, so greetd's session command is `island-session`, which runs `paint-vt` (all 16 console colours = cover colour,
  clear, no cursor; console = `/sys/class/tty/tty0/active`, XDG_VTNR isn't set) then `uwsm start` (output → `~/.local/state/island/session.log`). The greeter also paints at start.
- Test IPC only in scratch copies (tlock/tup/tpw/tenter/tok were added to the nested copy, not the real shell).

### Login screen (island-greeter, installed and working)
- Code `~/.config/quickshell/island-greeter/` (README). Installed copy `/usr/local/share/island-greeter`, data `/var/lib/island-greeter`
  (kept fresh by user unit `island-greeter-sync.path`). Falls back to `agreety` if it dies.
- After LockScreen.qml changes → `sudo …/island-greeter/install.sh`. **Run `check.sh` after `pacman -Syu` that updates
  Hyprland/quickshell, before rebooting.** Undo: `sudo …/uninstall.sh`.

---

## 6. QML lessons learned the hard way

- A `//` comment mid-line hides everything after it on that line.
- Don't name properties `top`, `left`, `focus`, `z` (FINAL → whole shell fails). One property per declaration.
- Don't give an id like `ed`, `bs`, `eb`, `eh`, `gap`, `ir` inside a `UiCandy` child: it resolves to UiCandy's own property.
- Inside a UiCandy, `parent` is its content holder — give the delegate an `id`.
- Inline `component` errors only say "X is not a type": move it to its own file to see the real error.
- `font.pixelSize` must be an integer. Two `onXChanged:` on one object = "set multiple times".
- QML JS has no `BigInt` and no regex `s` flag (use `[\s\S]`).
- A load error keeps the **previous** config running, and lazy parts (phone, snip editor, pickers) only error when opened → check `qs -c island log` after every edit and test lazy parts in the nested copy.
- Island doesn't watch prefs.json; to apply an outside edit, change a QML file's content.
- PyGObject can't implement `Gcr.Prompt` → talk D-Bus directly.
- `pkill -f <pattern>` in a tool shell can kill that shell — kill by PID.
- Hyprland colours in Lua are strings: `background_color = "rgb(ebd6d6)"`. A bare `0xEBD6D6` is accepted but means alpha 0 → black.

---

## 7. Performance

- **Island ≈ 470–495 MB RSS fresh** with `MALLOC_ARENA_MAX=2` (was ≈ 850 MB).
- **Hot reload leaks RAM** (one reload: 475 → 616 MB). After editing, restart fresh:
  ```sh
  qs -c island kill; sleep 1; hyprctl eval 'hl.exec_cmd("env MALLOC_ARENA_MAX=2 qs -c island")'
  pgrep -ax qs        # must be exactly ONE "qs -c island"
  ```
  Never `hyprctl dispatch 'hl.exec_cmd(…)'` (runs AND errors → two Islands). If two run, kill the newer PID.
- Lazy phone ≈ 100–120 MB per screen while it exists. Tested and **not** worth it: lazy power menu/dropdowns/etc., `QSG_RENDER_LOOP=basic`.
- Events: window list, clipboard, privacy (PipeWire), EN/VI, volume/mic. Timers: status 4 s (12 s gaming), bar stats 2 s (6 s gaming), weather 30 min.
- Quickshell UPower gives no data here → battery from sysfs.
- `tools/island-agents.py` = keyring prompter + Bluetooth agent in one Python. Only ONE gnome-keyring-daemon runs (checked 2026-10-22).
- WARP on demand: `tools/warp.sh on|off` (setup done; undo: `sudo …/tools/warp-ondemand-setup.sh undo`). WARP tray app masked.
- Kept on purpose: firewalld.

---

## 8. Open items

1. **Baseus Bass BP1 Pro mic (headset mode) is broken on Linux** — MT7922 drops voice packets ("SCO packet for unknown
   connection handle", "corrupted SCO packet") on both kernels. **Fix = USB Bluetooth dongle (Intel/Realtek).**
   WirePlumber `bluetooth.autoswitch-to-headset-profile = false` so apps don't switch to the broken mode.
   - Laptop mic instead: default source **"Laptop Mic (clear)"** (`mic_clean`, `~/.config/pipewire/pipewire.conf.d/60-mic-clean.conf`:
     high-pass 140 Hz, −4 dB @ 300 Hz, +3 dB @ 3.5 kHz). `hypr/scripts/mic-level.sh` sets Capture 23 / Boost 0 at login.
     Discord AGC must stay off. Don't install the acp6x DMIC driver (`~/.local/src/acp6x-ga402r/`, it's dead on GA402RJ).
2. **Wi-Fi dead after Windows** — see `WIFI-AFTER-WINDOWS-FIX.md`. Next time in Windows: turn off Wake-on-WLAN.
3. **Owner to confirm:** double-tap Ctrl rings; monitor hotplug (untested, no spare screen); phone window minimise to a workspace.
4. **Screen-share hang** after sharing one window: `systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal`, then restart OBS.
5. Keep: current files over the old `.pacnew` ones in /etc. Owner declined keyring auto-unlock.
6. **System facts** (don't suggest a cleanup unasked):
   - Never remove (look like orphans, but used): corepack rustup adw-gtk-theme ddcutil gnome-text-editor qview nwg-look swash
     xorg-xhost hyprland kitty uwsm xdg-desktop-portal-hyprland wl-clipboard grim slurp brightnessctl gnome-keyring hyprpicker qt6ct.
   - Owner keeps: firewalld, game launchers, btop, kcalc, LibreOffice, Wine, netctl, coding tools.
   - Kernel cmdline has debug `loglevel=7` not in /etc/default/grub (hand-edited grub.cfg; regenerating changes it).
   - If games feel slow on AC: check asusctl / power-profile / EPP (once found stuck in Quiet).
   - Docker is socket-activated (~150 MB when woken).

## 8b. Wish list (owner, 2026-10-21)

Pictures: `Md_File/todo-refs/`. Designs: `~/Downloads/isla-handoff/design/png/` (Edit-Desktop, Widgets, Lock, Wallpapers).
The owner now **wants desktop widgets** (through Edit Desktop). Done so far: Ctrl+S turn, phone window, wallpaper live preview.

**Status** — the live list is the to-do board **"Rice wish list"** (`~/Documents/Todo/Rice wish list.md`, bar ✓ card).
Add, tick or remove wishes THERE; this block is rewritten from it (`island/tools/wishlist-sync.py`) on every save:

<!-- wishlist:start — copied from ~/Documents/Todo/Rice wish list.md (Island ✓ card): edit the board, not this -->
- [ ] Right-click empty desktop → menu: Edit Desktop · Wallpapers · Group themes (candy card)
    - [right-click-desktop-menu.png](</home/gamer/Documents/Md_File/todo-refs/right-click-desktop-menu.png>)
- [ ] Edit Desktop mode: framed preview, tray tabs Widgets / Bar / Theme / Presets, drag with snap guides, Lock all, Done
- [ ] More widgets: clocks, date, user card, weather, calendar, to-do list, visualizer, music, stats (several styles each)
    - [widget-sheet-examples.png](</home/gamer/Documents/Md_File/todo-refs/widget-sheet-examples.png>)
- [ ] More themes (wait until I pick them): a theme sets UI style + widget style; Presets = saved layouts
- [x] New lock / login flow
- [ ] Making Phone app and for this system to connect them light weight when running in the background  connect phone notification to this system  connect let me control this system one the phone
- [ ] check update diskmap currently it kinda bad
- [ ] Adding a website display image wallpaper
- [ ] Check the git install  work for all system  and my fresh system
- [ ] Island task manager in the System card: top apps grouped (Helium = 1 row), icon, CPU %, RAM (PSS), End button; lazy, only polls while open; keep Open btop for full view; helper in C (7 ms/tick vs Python 32 ms, ~0.35% CPU at 2 s), install.sh compiles it
<!-- wishlist:end -->

**Details** (reference notes for the wishes above):

1. **Right-click empty desktop → menu:** Edit Desktop · Wallpapers · Group themes (candy card, see todo-refs picture).
2. **Edit Desktop mode:** desktop shrinks into a framed preview; bottom tray tabs **Widgets / Bar / Theme / Presets**;
   left click add/edit, right click remove, drag to move with snap guides (centre line, same width); picked widget shows
   handles + "style 1/3"; **Lock all**, **Done**. Positions saved per monitor. Bar tab edits/reorders bar pieces.
3. **More widgets** (after 2): clocks, date, user card, weather, calendar, to-do list, bottom visualizer, music, stats —
   several styles each. Also from widget-sheet-examples.png: "Started recording this monitor" pill, "Mic in use by … — click to mute" pill.
4. **More themes — WAIT until the owner picks them.** A theme sets UI style + widget style; Presets = saved layouts.
5. ~~New lock / login flow~~ **done 2026-10-22** (see §5 "Lock / login").

## 9. Quick commands

```sh
qs -c island log                 # Island log (errors after edits)
qs -c island kill; sleep 1; hyprctl eval 'hl.exec_cmd("env MALLOC_ARENA_MAX=2 qs -c island")'   # restart Island (§7)
pgrep -ax qs                   # exactly one Island?
qs -c island ipc call island phone settingsQuick   # open a phone page
hyprctl configerrors           # Hyprland config errors
dotfiles-sync "message"        # commit + push configs
```
