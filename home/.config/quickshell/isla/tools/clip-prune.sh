#!/bin/bash
# Clipboard cleanup (run by clip-store.sh at most once an hour): deletes unpinned cliphist items copied more than
# Prefs.clipDays (default 15) days ago, and the preview images / copy times of items that are gone.
# Pins are never touched (they also keep their own copy in ~/.local/share/isla/clip-pins).
prefs="$HOME/.local/state/isla/prefs.json"; times="$HOME/.cache/isla/cliptimes"
days=$(jq -r '.clipDays // 15' "$prefs" 2>/dev/null); [ "$days" -gt 0 ] 2>/dev/null || days=15
cut=$(( $(date +%s) - days * 86400 ))
# cliphist ids only grow → everything up to the newest id copied before the cutoff is old (also ones with no time)
old=$(awk -v c="$cut" '$2 < c && $1 > m { m = $1 } END { print m + 0 }' "$times" 2>/dev/null)
if [ "${old:-0}" -gt 0 ]; then
    cliphist list | awk -F'\t' -v o="$old" 'NR==FNR { p[$0]; next } $1 <= o && !(substr($0, index($0, "\t") + 1) in p)' \
        <(jq -r '.clipPins[]?' "$prefs" 2>/dev/null) - | cliphist delete
    awk -v c="$cut" '$2 >= c' "$times" > "$times.tmp" && mv "$times.tmp" "$times"
fi
# preview images of items no longer in the history
ids=" $(cliphist list | cut -f 1 | tr '\n' ' ')"
for f in "$HOME"/.cache/isla/clip-*.png; do
    [ -e "$f" ] || continue
    id=${f##*/clip-}; id=${id%.png}
    case "$ids" in *" $id "*) ;; *) rm -f "$f" ;; esac
done
