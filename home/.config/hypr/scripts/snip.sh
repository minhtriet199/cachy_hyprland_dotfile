#!/bin/sh
# Print: select a region, then draw on it in Island's snip editor (SnipEditor.qml).
# Enter = save to ~/Pictures/screenshot + copy · Esc = copy only (with the drawing, if any).

# Grab every screen FIRST, then freeze (hyprpicker draws a still frame over them) so the moment is
# captured even if a game/video keeps moving. The snip is cut from that first grab: grabbing the frozen
# frame instead converts the colours twice on an HDR screen and the snip looks burnt (too much contrast).
tmp=$(mktemp -d); trap 'kill $freeze 2>/dev/null; rm -rf "$tmp"' EXIT
# remember the pointer: if it gets thrown to the top-left corner (focus jumping between screens), put it back
pos=$(hyprctl cursorpos)
unjump() { case "$(hyprctl cursorpos)" in "0, 0"|"0, "[0-9]|"0, "[0-9][0-9]|[0-9]", 0"|[0-9][0-9]", 0")
    hyprctl dispatch "hl.dsp.cursor.move({ x = ${pos%%,*}, y = ${pos##* } })" >/dev/null;; esac; }
mons=$(hyprctl -j monitors | python3 -c 'import json,sys
for m in json.load(sys.stdin):
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    print(m["name"], m["x"], m["y"], round(w / m["scale"]), round(h / m["scale"]), m["scale"])')
# raw (ppm) grabs: ~0.05 s each instead of ~0.5 s for png, so the freeze shows up right away
echo "$mons" | { while read -r name _; do grim -t ppm -o "$name" "$tmp/$name.ppm" & done; wait; }

hyprpicker -r -z -d -q &
freeze=$!
sleep 0.15                         # let the frozen frame appear
unjump

# Dark dim outside the selection, selection itself stays clear, white border
region=$(slurp -b "#00000080" -s "#00000000" -c "#ffffffcc" -w 2) || { unjump; exit 0; }   # Esc cancels

# the cut goes to the Island snip editor (SnipEditor.qml): Enter = save to ~/Pictures/screenshot + copy, Esc = copy only
out="${XDG_RUNTIME_DIR:-/tmp}/island-snip"; mkdir -p "$out"; rm -f "$out"/*
file="$out/snip-$(date +%Y%m%d-%H%M%S).png"

# region = "X,Y WxH" (logical px). Cut it from the screen it sits on; across two screens → grab live.
# prints: MONITOR CROP(device px) X Y W H(logical, on that screen) SCALE
crop=$(echo "$mons" | python3 -c 'import sys
x, y = map(int, sys.argv[1].split()[0].split(",")); w, h = map(int, sys.argv[1].split()[1].split("x"))
rows = [l.split() for l in sys.stdin]
for n, mx, my, mw, mh, s in rows:
    mx, my, mw, mh, s = int(mx), int(my), int(mw), int(mh), float(s)
    if mx <= x and my <= y and x + w <= mx + mw and y + h <= my + mh:
        print(n, "%dx%d+%d+%d" % (round(w * s), round(h * s), round((x - mx) * s), round((y - my) * s)), x - mx, y - my, w, h, s); break
else:   # spans screens: show it on the one holding its top-left corner
    for n, mx, my, mw, mh, s in rows:
        mx, my, mw, mh = int(mx), int(my), int(mw), int(mh)
        if mx <= x < mx + mw and my <= y < my + mh:
            print(n, "-", x - mx, y - my, w, h, s); break' "$region")
set -- $crop
if [ "$2" != "-" ] && [ -f "$tmp/$1.ppm" ]; then
    magick "$tmp/$1.ppm" -crop "$2" +repage "$file" || exit 1
else
    kill $freeze 2>/dev/null; sleep 0.05; grim -g "$region" "$file" || exit 1
fi
[ -n "$1" ] && [ -f "$tmp/$1.ppm" ] && mv "$tmp/$1.ppm" "$out/screen.ppm"

if [ -n "$1" ] && qs -c island ipc call island snip "$file|$out/screen.ppm|$1|$3|$4|$5|$6|$7" >/dev/null 2>&1; then
    sleep 0.35                     # editor is up over the frozen frame: now let go of the freeze
    kill $freeze 2>/dev/null; unjump
    exit 0
fi
# Island not running: old way — copy, notify
kill $freeze 2>/dev/null; unjump
wl-copy --type image/png < "$file"
notify-send -a "Screenshot" -i "$file" "Screenshot copied" "Paste with Ctrl + V"
