#!/bin/sh
# Super + S: select a region, copy it to the clipboard (like Windows Snipping Tool).
# Click the notification to edit the image in swash.

# Grab every screen FIRST, then freeze (hyprpicker draws a still frame over them) so the moment is
# captured even if a game/video keeps moving. The snip is cut from that first grab: grabbing the frozen
# frame instead converts the colours twice on an HDR screen and the snip looks burnt (too much contrast).
tmp=$(mktemp -d); trap 'kill $freeze 2>/dev/null; rm -rf "$tmp"' EXIT
mons=$(hyprctl -j monitors | python3 -c 'import json,sys
for m in json.load(sys.stdin):
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    print(m["name"], m["x"], m["y"], round(w / m["scale"]), round(h / m["scale"]), m["scale"])')
echo "$mons" | { while read -r name _; do grim -o "$name" "$tmp/$name.png" & done; wait; }

hyprpicker -r -z -d -q &
freeze=$!
sleep 0.15                         # let the frozen frame appear

# Dark dim outside the selection, selection itself stays clear, white border
region=$(slurp -b "#00000080" -s "#00000000" -c "#ffffffcc" -w 2) || exit 0   # Esc cancels

dir="$HOME/Pictures/screenshot"
mkdir -p "$dir"
file="$dir/snip-$(date +%Y%m%d-%H%M%S).png"

# region = "X,Y WxH" (logical px). Cut it from the screen it sits on; across two screens → grab live.
crop=$(echo "$mons" | python3 -c 'import sys
x, y = map(int, sys.argv[1].split()[0].split(",")); w, h = map(int, sys.argv[1].split()[1].split("x"))
for line in sys.stdin:
    n, mx, my, mw, mh, s = line.split(); mx, my, mw, mh, s = int(mx), int(my), int(mw), int(mh), float(s)
    if mx <= x and my <= y and x + w <= mx + mw and y + h <= my + mh:
        print(n, "%dx%d+%d+%d" % (round(w * s), round(h * s), round((x - mx) * s), round((y - my) * s))); break' "$region")
kill $freeze 2>/dev/null           # unfreeze right away
if [ -n "$crop" ] && [ -f "$tmp/${crop%% *}.png" ]; then
    magick "$tmp/${crop%% *}.png" -crop "${crop#* }" +repage "$file" || exit 1
else
    sleep 0.05; grim -g "$region" "$file" || exit 1
fi
wl-copy --type image/png < "$file"

action=$(notify-send -a "Screenshot" -i "$file" -A default=Open --wait \
    "Screenshot copied" "Paste with Ctrl + V · click to edit")
[ "$action" = "default" ] && swash "$file"
