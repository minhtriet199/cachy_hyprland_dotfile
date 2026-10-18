#!/bin/sh
# Clipboard history saver (autostart: wl-paste --watch this). Same as `cliphist store`, and also writes
# down when it was copied ("<id> <unix time>" in ~/.cache/isla/cliptimes) so the phone can show the time.
cliphist store || exit 0
id=$(cliphist list | head -n 1 | cut -f 1)
[ -n "$id" ] || exit 0
f="$HOME/.cache/isla/cliptimes"
mkdir -p "${f%/*}"
echo "$id $(date +%s)" >> "$f"
# keep the file small
[ "$(wc -l < "$f")" -gt 2000 ] && tail -n 1000 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
exit 0
