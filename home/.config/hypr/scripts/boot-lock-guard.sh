#!/bin/sh
# Auto-login safety. `island-session autologin` leaves $XDG_RUNTIME_DIR/isla-autologin until the first unlock and Island
# starts locked. If Island isn't running (crash, broken config…) while that file is there, lock with hyprlock instead
# (~/.config/hypr/hyprlock.conf) so the session is never left open; its unlock counts as the login. If hyprlock can't
# start either, end the session: greetd then shows the Island login screen. With that login screen there is nothing to guard.
m="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/isla-autologin"
[ -e "$m" ] || exit 0
sleep 10
fails=0
while [ -e "$m" ]; do
    if ! pgrep -x qs >/dev/null && ! pgrep -x quickshell >/dev/null && ! pidof hyprlock >/dev/null; then
        if hyprlock; then "$HOME/.config/hypr/scripts/after-unlock.sh"
        else
            fails=$((fails + 1))
            [ "$fails" -ge 3 ] && { hyprctl dispatch 'hl.dsp.exit()'; exit 1; }
        fi
    fi
    sleep 3
done
