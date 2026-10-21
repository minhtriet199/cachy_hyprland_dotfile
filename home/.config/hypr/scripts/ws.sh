#!/bin/sh
# Separate workspaces per monitor, picked by where the MOUSE is.
#   External screen (any port): workspaces 1-9
#   Laptop (eDP-1/eDP-2): workspaces 11-19 (labelled 1-9)
# usage: ws.sh go|move N
action="$1"
n="$2"

# Monitor under the mouse cursor
pos=$(hyprctl cursorpos)          # "x, y"
cx=${pos%%,*}; cy=${pos##*, }
mon=$(hyprctl monitors -j | jq -r --argjson x "$cx" --argjson y "$cy" '
    .[] | select($x >= .x and $x < .x + (.width / .scale)
             and $y >= .y and $y < .y + (.height / .scale)) | .name' | head -1)

case "$mon" in eDP-*) n=$((n + 10)) ;; esac

case "$action" in
    go)   hyprctl dispatch "hl.dsp.focus({ workspace = $n })" >/dev/null ;;
    move) hyprctl dispatch "hl.dsp.window.move({ workspace = $n })" >/dev/null ;;
    *)    echo "usage: $0 go|move N" >&2; exit 1 ;;
esac
