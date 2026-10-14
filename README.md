# CachyOS + Hyprland dotfiles

My setup for ASUS ROG G14 (CachyOS + Hyprland + Noctalia). Restores my whole
desktop after a reinstall, and keeps itself updated.

## Restore on a fresh CachyOS install
```sh
git clone https://github.com/minhtriet199/cachy_hyprland_dotfile.git ~/dotfiles
cd ~/dotfiles
./install.sh
```
Then log out/in. See the notes install.sh prints for the few manual steps
(GitHub login, browser/Steam sign-ins, Wi-Fi/Bluetooth).

## What's inside
- `home/.config/hypr/` — Hyprland config (Lua) and all my scripts
- `home/.config/noctalia/` + `settings.toml` — Noctalia shell config
- `home/.config/systemd/user/` — screen-time archiver, Godot-Vulkan fixer
- `home/.local/share/applications/` — my custom apps' launchers
- `system/` — DNS hardening, firewall service, SSH toggle (installed with sudo)
- `packages-native.txt`, `packages-aur.txt` — every installed app

## My custom apps (in ~/.config/hypr/scripts)
- **Screen Settings** — brightness, HDR, resolution, refresh, scale per screen
- **Keyboard Shortcuts** — edit Hyprland keybinds in a window
- **Screen Time** — daily usage + 31-day history
- **Network Settings** — Wi-Fi, DNS, IP, devices on the network, SSH toggle
- **File Sharing toggle** — open LAN sharing ports for 15 min

## Keeping it updated
```sh
~/dotfiles/dotfiles-sync "what I changed"
```
Copies the latest config in, commits with that message, and pushes.
