#!/bin/sh
# Auto-login safety: Isla should lock the screen right after login. If Isla isn't running a few seconds
# after Hyprland starts (crash, broken config…), lock with hyprlock instead so the session is never left open.
# With the real Isla login screen (no auto-login in /etc/greetd/config.toml) there is nothing to guard.
grep -q '^\[initial_session\]' /etc/greetd/config.toml 2>/dev/null || exit 0
sleep 10
if ! pgrep -x qs >/dev/null && ! pgrep -x quickshell >/dev/null; then
    pidof hyprlock >/dev/null || hyprlock
fi
