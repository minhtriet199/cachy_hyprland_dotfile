#!/bin/sh
# Clipboard history saver (autostart: wl-paste --watch this). Same as `cliphist store`, and also writes
# down when it was copied ("<id> <unix time>" in ~/.cache/island/cliptimes) so the phone can show the time.
[ "$CLIPBOARD_STATE" = sensitive ] && exit 0      # hidden pins are copied as sensitive: keep them out of the history
types=$(wl-paste --list-types 2>/dev/null)
# while a snip runs (snip.sh drops this flag) focus moves twice (freeze, then the editor) and Steam / XWayland games
# re-send an old clipboard text each time, also right after the snip image lands → skip text until 10 s after the image
snip="${XDG_RUNTIME_DIR:-/tmp}/island-snipping"
if [ -f "$snip" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$snip") ))
    if printf '%s\n' "$types" | grep -q '^image/'; then
        [ "$(cat "$snip")" = done ] || echo done > "$snip"
    elif [ "$age" -lt 60 ] && [ "$(cat "$snip")" != done ] || [ "$age" -lt 10 ]; then
        cat >/dev/null; exit 0
    else
        rm -f "$snip"
    fi
fi
# a picture copied in a browser comes with text/html, a UTF-16 "data:image/..." text etc. but no plain text, and
# wl-paste --watch hands us one of those text ones → keep the picture itself (png if offered)
img=""
printf '%s\n' "$types" | grep -qE '^(text/plain|UTF8_STRING|STRING|TEXT)' ||
    img=$(printf '%s\n' "$types" | grep -m1 -x 'image/png' || printf '%s\n' "$types" | grep -m1 '^image/')
if [ -n "$img" ]; then
    cat >/dev/null; wl-paste --no-newline --type "$img" | cliphist store || exit 0
else
    # a text already in the recent history isn't stored again (XWayland re-sends would bubble an old one back up)
    t=$(mktemp); cat > "$t"
    if printf '%s\n' "$types" | grep -qE '^(text/|UTF8_STRING|STRING|TEXT)' && [ -s "$t" ] &&
       cliphist list | head -n 30 | cut -f 1 | while read -r i; do if cliphist decode "$i" 2>/dev/null | cmp -s - "$t"; then exit 1; fi; done; [ $? = 1 ]; then
        rm -f "$t"; exit 0
    fi
    cliphist store < "$t"; rc=$?; rm -f "$t"; [ $rc = 0 ] || exit 0
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
