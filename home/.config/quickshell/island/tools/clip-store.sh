#!/bin/sh
# Clipboard history saver (autostart: wl-paste --watch this). Same as `cliphist store`, and also writes
# down when it was copied ("<id> <unix time>" in ~/.cache/island/cliptimes) so the phone can show the time.
[ "$CLIPBOARD_STATE" = sensitive ] && exit 0      # hidden pins are copied as sensitive: keep them out of the history
# a Steam game (XWayland/Proton) hands its own clipboard text over whenever it loses focus (e.g. Super+S snip):
# skip text while a game is focused, keep images (the snip itself)
case "$(hyprctl activewindow -j 2>/dev/null)" in *'"class": "steam_app_'*)
    wl-paste --list-types 2>/dev/null | grep -q '^image/' || { cat >/dev/null; exit 0; } ;; esac
cliphist store || exit 0
id=$(cliphist list | head -n 1 | cut -f 1)
[ -n "$id" ] || exit 0
f="$HOME/.cache/island/cliptimes"
mkdir -p "${f%/*}"
echo "$id $(date +%s)" >> "$f"
# keep the file small
[ "$(wc -l < "$f")" -gt 2000 ] && tail -n 1000 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
# old-item cleanup, at most once an hour
st="$HOME/.cache/island/clip-pruned"
[ -n "$(find "$st" -mmin -60 2>/dev/null)" ] || { touch "$st"; "${0%/*}/clip-prune.sh" >/dev/null 2>&1 & }
exit 0
