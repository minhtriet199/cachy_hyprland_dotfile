#!/bin/sh
# Install the Isla login screen and make greetd use it. Run:
#   sudo ./install.sh            login screen at boot (a second Hyprland, so a short switch after the password)
#   sudo ./install.sh autologin  boot straight into your Hyprland, locked: the Isla lock screen is the login (one
#                                Hyprland, no switch). The login screen is still used after you log out.
# Takes effect at the next boot (greetd is not restarted, your session keeps running).
# Undo: sudo ./uninstall.sh   (or from a text console: Ctrl+Alt+F2, log in, run the same command)
set -eu
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
user="${SUDO_USER:?run with sudo from your own account}"
uhome=$(getent passwd "$user" | cut -d: -f6)
here="$(cd "$(dirname "$0")" && pwd)"
share=/usr/local/share/isla-greeter
data=/var/lib/isla-greeter
mode="${1:-}"
[ -z "$mode" ] || [ "$mode" = autologin ] || { echo "usage: sudo $0 [autologin]"; exit 1; }

command -v Hyprland >/dev/null && command -v qs >/dev/null && command -v agreety >/dev/null || { echo "Hyprland, qs and agreety are needed"; exit 1; }
getent passwd greeter >/dev/null || { echo "no 'greeter' user (comes with greetd)"; exit 1; }

echo "1/4 copy the login screen to $share"
tmp=$(mktemp -d)
ISLA_DIR="$uhome/.config/quickshell/isla" sh "$here/build.sh" "$tmp"
rm -rf "$share"; mkdir -p "$share"; cp -r "$tmp"/. "$share"/; rm -rf "$tmp"
chown -R root:root "$share"; chmod -R u=rwX,go=rX "$share"; chmod 755 "$share/isla-greeter-session" "$share/run-greeter"

echo "2/4 data folder $data (yours, readable by the greeter) + the greeter's home"
install -d -o "$user" -g "$user" -m 755 "$data"
install -d -o greeter -g greeter -m 700 "$data/home"
sudo -u "$user" ISLA_GREETER_DATA="$data" HOME="$uhome" USER="$user" sh "$here/isla-greeter-sync"

cfg=/etc/greetd/config.toml
[ -f /etc/greetd/config.toml.before-isla ] || cp -a "$cfg" /etc/greetd/config.toml.before-isla
if [ "$mode" = autologin ]; then
    for f in after-unlock.sh boot-lock-guard.sh; do
        [ -x "$uhome/.config/hypr/scripts/$f" ] || { echo "missing $uhome/.config/hypr/scripts/$f — not turning on auto-login"; exit 1; }
    done
    echo "3/4 greetd: boot into your Hyprland, locked (Isla lock screen = login); Isla login screen after log out"
    autologin=$(printf '\n[initial_session]\ncommand = "%s/isla-session autologin"\nuser = "%s"\n' "$share" "$user")
else
    echo "3/4 greetd: Isla login screen, no auto-login"
    autologin=""
fi
cat > "$cfg" <<CFG
# Isla login screen (~/.config/quickshell/isla-greeter). Previous config: config.toml.before-isla
[terminal]
vt = 1

[default_session]
command = "$share/isla-greeter-session"
user = "greeter"
$autologin
CFG

echo "4/4 done. Reboot to see it. If it ever fails you get a text login; undo with: sudo $here/uninstall.sh"
