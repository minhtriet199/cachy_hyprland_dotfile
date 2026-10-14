#!/usr/bin/env bash
# Restore this setup on a fresh CachyOS install.
#   cd ~/dotfiles && ./install.sh
# Safe to re-run. Review the steps; it asks for sudo where needed.
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

say "1/5  Installing packages from the official repos"
sudo pacman -S --needed --noconfirm - < "$REPO/packages-native.txt" || echo "some packages skipped"

say "2/5  Installing AUR packages"
if command -v paru >/dev/null; then
    paru -S --needed --noconfirm - < "$REPO/packages-aur.txt" || echo "some AUR packages skipped"
else
    echo "No AUR helper found. Install 'paru' then run:  paru -S --needed - < $REPO/packages-aur.txt"
    echo "AUR packages needed: $(tr '\n' ' ' < "$REPO/packages-aur.txt")"
fi

say "3/5  Copying your config, scripts and app launchers into \$HOME"
rsync -a "$REPO/home/" "$HOME/"
chmod +x "$HOME"/.config/hypr/scripts/*.sh "$HOME"/.config/hypr/scripts/*.py 2>/dev/null

say "4/5  Installing system files (DNS hardening, SSH toggle helper, firewall service)"
sudo install -Dm644 "$REPO/system/etc/systemd/resolved.conf.d/no-llmnr.conf"   /etc/systemd/resolved.conf.d/no-llmnr.conf
sudo install -Dm644 "$REPO/system/etc/systemd/resolved.conf.d/dns-over-tls.conf" /etc/systemd/resolved.conf.d/dns-over-tls.conf
sudo install -Dm755 -o root -g root "$REPO/system/usr/local/bin/ssh-toggle"    /usr/local/bin/ssh-toggle
sudo install -Dm440 "$REPO/system/etc/sudoers.d/ssh-toggle"                    /etc/sudoers.d/ssh-toggle
sudo install -Dm644 "$REPO/system/etc/firewalld/services/steam-remote-play.xml" /etc/firewalld/services/steam-remote-play.xml

say "5/5  Enabling services"
systemctl --user daemon-reload
systemctl --user enable --now screentime-archive.timer godot-vulkan-fix.path godot-vulkan-fix.timer 2>/dev/null
sudo systemctl enable --now firewalld
sudo systemctl restart systemd-resolved
[ -x "$HOME/.config/hypr/scripts/firewall-setup.sh" ] && sudo "$HOME/.config/hypr/scripts/firewall-setup.sh"

cat <<'NOTE'

Done. A few things still to do by hand:
  - Log out and back in (or reboot) so Hyprland/Noctalia pick everything up.
  - gh auth login            (to push dotfile updates again)
  - Helium: Settings -> On startup -> "Continue where you left off", then sign in.
  - Sign in to Steam, Helium, etc.
  - Re-pair Bluetooth devices and re-enter Wi-Fi passwords if needed.
NOTE
