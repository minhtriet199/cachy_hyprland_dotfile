# Island login screen (greeter)

Island's own `LockScreen.qml` (with `greeter: true`) as the real greetd login screen, instead of
auto-login + Island locking itself.

| File | What |
|---|---|
| `shell.qml` | session lock + LockScreen; talks to greetd (`Quickshell.Services.Greetd`). Without greetd (test) it checks your password with PAM and quits |
| `Prefs.qml` / `Svc.qml` | read-only prefs + clock/battery/name/power for LockScreen |
| `greeter.lua` | tiny Hyprland config for the greeter (screen layout from the data folder, no HDR) |
| `run-greeter` | runs `qs -p` then exits that Hyprland |
| `island-greeter-session` | greetd `default_session`. Falls back to `agreety` (text login) if the greeter dies without logging in |
| `island-session` / `paint-vt` | your session command (paints the text console in the cover colour, then `uwsm start … Hyprland`; uwsm log → `~/.local/state/island/session.log`) / the painter, also used by the greeter |
| `build.sh` | copies (never links) the needed Island files + these into one folder |
| `island-greeter-sync` | copies prefs.json, lock wallpaper, screens, name → `/var/lib/island-greeter` (run by `island-greeter-sync.path`) |
| `install.sh` / `uninstall.sh` | `sudo` — install to `/usr/local/share/island-greeter`, switch greetd (backup `config.toml.before-island`) / undo |

**Auto-login mode** (`sudo ./install.sh autologin`): greetd boots straight into your Hyprland (`island-session autologin`,
one Hyprland → no black switch after the password). It leaves `$XDG_RUNTIME_DIR/isla-autologin` = "not logged in yet":
Island starts locked (its lock screen is the login), Hyprland starts in the empty `bootlock` submap (hypr
`config/autostart.lua`) and holds startup apps (`config/startup_island.lua`). The first unlock runs hypr
`scripts/after-unlock.sh` (removes the mark, shortcuts back, startup apps). If Island isn't running, hypr
`scripts/boot-lock-guard.sh` locks with hyprlock (`~/.config/hypr/hyprlock.conf`); if that fails 3× it ends the session →
this login screen. After log out you always get this login screen. Back to login-screen-only: `sudo ./install.sh`.

**After `pacman -Syu` (Hyprland/quickshell updates) or Island lock-screen changes, before rebooting:** `./check.sh`
(installed copy) or `./check.sh --fresh` (current Island files). It logs in by itself against `fake-greetd.py`
(password `island-test`, env `ISLAND_GREETER_TEST=1`) and tests the text-login fallback.

Manual test in a window: `./build.sh /tmp/g && ./island-greeter-sync` (with `ISLAND_GREETER_DATA=/tmp/gd`) then
`ISLAND_GREETER_SHARE=/tmp/g ISLAND_GREETER_DATA=/tmp/gd Hyprland -c /tmp/g/greeter.lua` (nested).

After changing LockScreen.qml or any copied Island file: run `sudo ./install.sh` again (the greeter uses its own copy).
Logs: `/var/lib/island-greeter/home/greeter.log`, qs log in the greeter's runtime dir (`/tmp/island-greeter-<uid>/island-greeter-qs.log` or `/run/user/<uid>/`).
