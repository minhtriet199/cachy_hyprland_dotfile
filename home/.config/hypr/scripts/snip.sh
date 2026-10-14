#!/bin/sh
# Super + S: select a region, copy it to the clipboard (like Windows Snipping Tool).
# Click the notification to edit the image in swash.

# Freeze every screen first (hyprpicker draws a still frame over them),
# so the moment is captured even if a game/video keeps moving.
hyprpicker -r -z -d -q &
freeze=$!
trap 'kill $freeze 2>/dev/null' EXIT
sleep 0.15                         # let the frozen frame appear

# Dark dim outside the selection, selection itself stays clear, white border
region=$(slurp -b "#00000080" -s "#00000000" -c "#ffffffcc" -w 2) || exit 0   # Esc cancels

dir="$HOME/Pictures/screenshot"
mkdir -p "$dir"
file="$dir/snip-$(date +%Y%m%d-%H%M%S).png"

grim -g "$region" "$file" || exit 1
kill $freeze 2>/dev/null           # unfreeze right away
wl-copy --type image/png < "$file"

action=$(notify-send -a "Screenshot" -i "$file" -A default=Open --wait \
    "Screenshot copied" "Paste with Ctrl + V · click to edit")
[ "$action" = "default" ] && swash "$file"
