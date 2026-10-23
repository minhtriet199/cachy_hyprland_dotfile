#!/bin/bash
# The 5 main colours of a picture, most used first (one #rrggbb per line).
#   palette.sh <file path | file:// URL | http(s) URL (album art)>
src="$1"
case "$src" in
    http://*|https://*) f="${XDG_RUNTIME_DIR:-/tmp}/island-palette-src"; curl -s --max-time 8 -o "$f" "$src" || exit 1; src="$f" ;;
    file://*) src="${src#file://}"; src=$(printf '%b' "${src//%/\\x}") ;;
esac
[ -f "$src" ] || exit 1
magick "${src}[0]" -resize 160x160 -colors 5 -depth 8 -format "%c" histogram:info:- 2>/dev/null \
    | sort -rn | grep -o '#[0-9A-Fa-f]\{6\}' | head -5
