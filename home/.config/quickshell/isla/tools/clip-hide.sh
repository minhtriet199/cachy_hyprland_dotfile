#!/bin/sh
# Super+Shift+C: presses copy in the focused app (Ctrl+C, Ctrl+Shift+C in terminals), saves what it copied as a hidden
# pin in the dot-folder ~/.local/share/isla/.k (only Super+Shift+V shows them), then takes it back out of the history
# and puts the old clipboard back. Silent: no notification, so it looks like nothing happened. Nothing selected → nothing saved.
# (The selection itself can't be read: misc.lua has middle_click_paste = false, which turns the primary selection off.)
d="$HOME/.local/share/isla/.k"
umask 077; mkdir -p "$d"
sum() { wl-paste 2>/dev/null | md5sum; }
before=$(sum); old=$(cliphist list | head -n 1 | cut -f 1)
case $(hyprctl activewindow -j | jq -r .class) in
    kitty|foot|Alacritty|com.mitchellh.ghostty|org.wezfurlong.wezterm) mods="CTRL SHIFT" ;;
    *) mods="CTRL" ;;
esac
hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"$mods\", key = \"C\" })" >/dev/null
i=0; while [ "$(sum)" = "$before" ]; do i=$((i + 1)); [ $i -gt 10 ] && exit 0; sleep 0.05; done
f="$d/$(date +%s%3N)"
if wl-paste -l | grep -qx image/png; then f="$f.png"; wl-paste -t image/png > "$f"; else f="$f.txt"; wl-paste -n > "$f"; fi
# wait for clip-store.sh to put it in the history, delete it there, then give the clipboard its old content back
i=0; while [ $i -lt 20 ]; do
    l=$(cliphist list | head -n 1)
    [ "${l%%	*}" != "$old" ] && cliphist decode "${l%%	*}" | cmp -s - "$f" && { printf '%s\n' "$l" | cliphist delete; break; }
    i=$((i + 1)); sleep 0.05
done
[ -n "$old" ] && cliphist decode "$old" | wl-copy
