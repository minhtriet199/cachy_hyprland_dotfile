# Isla login screen (greeter)

Isla's own `LockScreen.qml` (with `greeter: true`) as the real greetd login screen, instead of
auto-login + Isla locking itself.

| File | What |
|---|---|
| `shell.qml` | session lock + LockScreen; talks to greetd (`Quickshell.Services.Greetd`). Without greetd (test) it checks your password with PAM and quits |
| `Prefs.qml` / `Svc.qml` | read-only prefs + clock/battery/name/power for LockScreen |
| `greeter.lua` | tiny Hyprland config for the greeter (screen layout from the data folder, no HDR) |
| `run-greeter` | runs `qs -p` then exits that Hyprland |
| `isla-greeter-session` | greetd `default_session`. Falls back to `agreety` (text login) if the greeter dies without logging in |
| `build.sh` | copies (never links) the needed Isla files + these into one folder |
| `isla-greeter-sync` | copies prefs.json, lock wallpaper, screens, name → `/var/lib/isla-greeter` (run by `isla-greeter-sync.path`) |
| `install.sh` / `uninstall.sh` | `sudo` — install to `/usr/local/share/isla-greeter`, switch greetd (backup `config.toml.before-isla`) / undo |

**After `pacman -Syu` (Hyprland/quickshell updates) or Isla lock-screen changes, before rebooting:** `./check.sh`
(installed copy) or `./check.sh --fresh` (current Isla files). It logs in by itself against `fake-greetd.py`
(password `isla-test`, env `ISLA_GREETER_TEST=1`) and tests the text-login fallback.

Manual test in a window: `./build.sh /tmp/g && ./isla-greeter-sync` (with `ISLA_GREETER_DATA=/tmp/gd`) then
`ISLA_GREETER_SHARE=/tmp/g ISLA_GREETER_DATA=/tmp/gd Hyprland -c /tmp/g/greeter.lua` (nested).

After changing LockScreen.qml or any copied Isla file: run `sudo ./install.sh` again (the greeter uses its own copy).
Logs: `/var/lib/isla-greeter/home/greeter.log`, qs log in the greeter's runtime dir (`/tmp/isla-greeter-<uid>/isla-greeter-qs.log` or `/run/user/<uid>/`).
