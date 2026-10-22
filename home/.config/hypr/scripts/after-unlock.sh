#!/bin/sh
# Auto-login: the first unlock is your login. Isla (or boot-lock-guard's hyprlock) runs this once, through Hyprland:
# shortcuts back on, then the startup apps from Isla Settings → Apps (held until now so nothing opens behind the lock).
m="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/isla-autologin"
[ -e "$m" ] || exit 0
rm -f "$m"
hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
grep '^1|' "$HOME/.local/state/hypr/startup" 2>/dev/null | cut -d'|' -f3- | while IFS= read -r cmd; do
    setsid -f sh -c "$cmd" >/dev/null 2>&1
done
