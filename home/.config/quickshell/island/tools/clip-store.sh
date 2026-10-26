#!/bin/sh
# Clipboard history saver (autostart: wl-paste --watch this). Same as `cliphist store`, and also writes
# down when it was copied ("<id> <unix time>" in ~/.cache/island/cliptimes) so the phone can show the time.
[ "$CLIPBOARD_STATE" = sensitive ] && exit 0      # hidden pins are copied as sensitive: keep them out of the history
# while a snip runs (snip.sh drops this flag), the window losing focus (XWayland games) re-sends its old clipboard
# text: skip text then, keep the snip image (which ends the snip)
types=$(wl-paste --list-types 2>/dev/null)
snip="${XDG_RUNTIME_DIR:-/tmp}/island-snipping"
if [ -n "$(find "$snip" -mmin -1 2>/dev/null)" ]; then
    printf '%s\n' "$types" | grep -q '^image/' && rm -f "$snip" || { cat >/dev/null; exit 0; }
fi
# a picture copied in a browser comes with text/html, a UTF-16 "data:image/..." text etc. but no plain text, and
# wl-paste --watch hands us one of those text ones → keep the picture itself (png if offered)
img=""
printf '%s\n' "$types" | grep -qE '^(text/plain|UTF8_STRING|STRING|TEXT)' ||
    img=$(printf '%s\n' "$types" | grep -m1 -x 'image/png' || printf '%s\n' "$types" | grep -m1 '^image/')
if [ -n "$img" ]; then
    cat >/dev/null; wl-paste --no-newline --type "$img" | cliphist store || exit 0
else
    cliphist store || exit 0
fi
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
