#!/bin/sh
# Super+Shift+C: saves the selected text — or, with nothing selected, what is on the clipboard — as a hidden
# pin in the dot-folder ~/.local/share/isla/.k (only Super+Shift+V shows them). Silent: no notification,
# so it looks like nothing happened. A clipboard copy is also taken back out of the normal clipboard history.
d="$HOME/.local/share/isla/.k"
umask 077; mkdir -p "$d"
f="$d/$(date +%s%3N)"
if [ -n "$(wl-paste -p -n 2>/dev/null | head -c 1)" ]; then
    wl-paste -p -n > "$f.txt"; f="$f.txt"
elif wl-paste -l 2>/dev/null | grep -qx image/png; then
    wl-paste -t image/png > "$f.png"; f="$f.png"
elif [ -n "$(wl-paste -n 2>/dev/null | head -c 1)" ]; then
    wl-paste -n > "$f.txt"; f="$f.txt"
else
    exit 0
fi
# the newest history item is this same copy (clipboard case) → delete it so it only lives in the hidden pins
cliphist list | head -n 1 | while IFS= read -r l; do
    cliphist decode "${l%%	*}" | cmp -s - "$f" && printf '%s\n' "$l" | cliphist delete
done
