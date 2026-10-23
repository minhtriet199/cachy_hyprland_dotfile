#!/bin/sh
# Install the Island login screen and make greetd use it. Run:
#   sudo ./install.sh            login screen at boot (a second Hyprland, so a short switch after the password)
#   sudo ./install.sh autologin  boot straight into your Hyprland, locked: the Island lock screen is the login (one
#                                Hyprland, no switch). The login screen is still used after you log out.
# Takes effect at the next boot (greetd is not restarted, your session keeps running).
# Undo: sudo ./uninstall.sh   (or from a text console: Ctrl+Alt+F2, log in, run the same command)
set -eu
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
user="${SUDO_USER:?run with sudo from your own account}"
uhome=$(getent passwd "$user" | cut -d: -f6)
here="$(cd "$(dirname "$0")" && pwd)"
share=/usr/local/share/island-greeter
data=/var/lib/island-greeter
mode="${1:-}"
[ -z "$mode" ] || [ "$mode" = autologin ] || { echo "usage: sudo $0 [autologin]"; exit 1; }

command -v Hyprland >/dev/null && command -v qs >/dev/null && command -v agreety >/dev/null || { echo "Hyprland, qs and agreety are needed"; exit 1; }
getent passwd greeter >/dev/null || { echo "no 'greeter' user (comes with greetd)"; exit 1; }

echo "1/4 copy the login screen to $share"
tmp=$(mktemp -d)
ISLAND_DIR="$uhome/.config/quickshell/island" sh "$here/build.sh" "$tmp"
rm -rf "$share"; mkdir -p "$share"; cp -r "$tmp"/. "$share"/; rm -rf "$tmp"
chown -R root:root "$share"; chmod -R u=rwX,go=rX "$share"; chmod 755 "$share/island-greeter-session" "$share/run-greeter"

echo "2/4 data folder $data (yours, readable by the greeter) + the greeter's home"
install -d -o "$user" -g "$user" -m 755 "$data"
install -d -o greeter -g greeter -m 700 "$data/home"
sudo -u "$user" ISLAND_GREETER_DATA="$data" HOME="$uhome" USER="$user" sh "$here/island-greeter-sync"

cfg=/etc/greetd/config.toml
# renamed from Isla (2026-10-23): keep the old backup of the pre-greeter config, drop the old installed copy
[ -f /etc/greetd/config.toml.before-isla ] && mv /etc/greetd/config.toml.before-isla /etc/greetd/config.toml.before-island
rm -rf /usr/local/share/isla-greeter /var/lib/isla-greeter
[ -f /etc/greetd/config.toml.before-island ] || cp -a "$cfg" /etc/greetd/config.toml.before-island
if [ "$mode" = autologin ]; then
    for f in after-unlock.sh boot-lock-guard.sh; do
        [ -x "$uhome/.config/hypr/scripts/$f" ] || { echo "missing $uhome/.config/hypr/scripts/$f — not turning on auto-login"; exit 1; }
    done
    echo "3/4 greetd: boot into your Hyprland, locked (Island lock screen = login); Island login screen after log out"
    autologin=$(printf '\n[initial_session]\ncommand = "%s/island-session autologin"\nuser = "%s"\n' "$share" "$user")
else
    echo "3/4 greetd: Island login screen, no auto-login"
    autologin=""
fi
cat > "$cfg" <<CFG
# Island login screen (~/.config/quickshell/island-greeter). Previous config: config.toml.before-island
[terminal]
vt = 1

[default_session]
command = "$share/island-greeter-session"
user = "greeter"
$autologin
CFG

echo "4/4 done. Reboot to see it. If it ever fails you get a text login; undo with: sudo $here/uninstall.sh"
