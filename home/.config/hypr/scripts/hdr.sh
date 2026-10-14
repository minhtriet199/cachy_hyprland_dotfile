#!/bin/sh
# Screen adjustment for external screens. Usage: hdr.sh toggle | up | down | set
#   toggle/up/down act on the focused external screen (keybinds)
#   set opens Screen Settings (brightness, HDR, resolution, refresh rate, scale)
# Real logic lives in screenctl.py; state in ~/.local/state/hypr/screens.
dir=$(dirname "$0")
case "$1" in
    set|"") exec python3 "$dir/screen-settings.py" ;;
    *)      exec python3 "$dir/screenctl.py" "$@" ;;
esac
