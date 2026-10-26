#!/bin/sh
# Which GPU Hyprland draws on, decided at login (called from ~/.config/uwsm/env, before Hyprland starts).
# Prints a value for AQ_DRM_DEVICES, or nothing = Hyprland's own pick.
#   A screen plugged into the RX 6700S (HDMI; also the laptop panel in Ultimate) → RX 6700S first: the desktop and games
#   are drawn where that screen is wired, no copies between the GPUs. Nothing there (Hybrid, laptop only) → nothing:
#   the 680M draws and the RX 6700S can sleep (battery).
# Safety: GPUs found by PCI address (card numbers can change between boots); anything odd → prints nothing.
# Failsafe: a pending mark is left here and cleared by Hyprland's autostart once the session is up (20 s in, Island
# running); if a session with the RX 6700S first never got that far, the next login skips it (then tries again after).
# Off switch: touch ~/.config/hypr/gpu-pick-off (e.g. from a text console, Ctrl+Alt+F3) → always Hyprland's own pick.
[ -e "$HOME/.config/hypr/gpu-pick-off" ] && exit 0
d=/dev/dri/by-path
dg=$(readlink -f "$d/pci-0000:03:00.0-card" 2>/dev/null)      # RX 6700S
ig=$(readlink -f "$d/pci-0000:07:00.0-card" 2>/dev/null)      # Radeon 680M
[ -c "$dg" ] && [ -c "$ig" ] || exit 0
mark="${XDG_CACHE_HOME:-$HOME/.cache}/island/gpu-pick-pending"
if [ -e "$mark" ]; then rm -f "$mark"; exit 0; fi              # last try didn't reach the desktop → normal start this time
on=""
for c in /sys/class/drm/"${dg##*/}"-*/status; do
    [ "$(cat "$c" 2>/dev/null)" = connected ] && on=1
done
[ -n "$on" ] || exit 0
mkdir -p "${mark%/*}" && : > "$mark"
printf '%s:%s\n' "$dg" "$ig"
