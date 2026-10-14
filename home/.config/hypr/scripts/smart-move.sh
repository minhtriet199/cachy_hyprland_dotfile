#!/bin/sh
# Super + Left/Right
#   floating window -> make it tiled again and move it to that side
#   tiled window    -> just move focus to that side
dir="$1"
case "$dir" in
    left)  d=l ;;
    right) d=r ;;
    *) echo "usage: $0 left|right" >&2; exit 1 ;;
esac

if hyprctl activewindow -j | grep -q '"floating": true'; then
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })' >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ direction = \"$d\" })" >/dev/null
else
    hyprctl dispatch "hl.dsp.focus({ direction = \"$dir\" })" >/dev/null
fi
