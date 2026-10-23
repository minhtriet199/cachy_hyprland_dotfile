#!/bin/sh
# Island → Wallpapers → Paste image: save the clipboard image (or download a copied image link) into ~/Pictures/Wallpapers.
# Prints the saved file path. Exit 2 = nothing usable on the clipboard, 3 = the link wasn't a picture.
d="$HOME/Pictures/Wallpapers"; mkdir -p "$d"
base="$d/pasted-$(date +%Y%m%d-%H%M%S)"
types=$(wl-paste --list-types 2>/dev/null)
for t in image/png image/jpeg image/webp image/gif; do
    if printf '%s\n' "$types" | grep -qx "$t"; then
        ext=${t#image/}; [ "$ext" = jpeg ] && ext=jpg
        wl-paste -t "$t" > "$base.$ext" && { echo "$base.$ext"; exit 0; }
    fi
done
url=$(wl-paste -n 2>/dev/null | head -n1 | tr -d '[:space:]')
case "$url" in
    http://*|https://*) ;;
    *) exit 2 ;;
esac
tmp="$base.download"
curl -fsSL --max-time 40 -A "Mozilla/5.0" -o "$tmp" "$url" || { rm -f "$tmp"; exit 3; }
mime=$(file -b --mime-type "$tmp")
case "$mime" in
    image/png) ext=png ;; image/jpeg) ext=jpg ;; image/webp) ext=webp ;; image/gif) ext=gif ;;
    *) rm -f "$tmp"; exit 3 ;;
esac
mv "$tmp" "$base.$ext" && echo "$base.$ext"
