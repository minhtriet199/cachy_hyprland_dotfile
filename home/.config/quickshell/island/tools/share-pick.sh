#!/bin/sh
# Screen-share picker for xdg-desktop-portal-hyprland (hypr/xdph.conf: custom_picker_binary).
# Anything that asks to record or share the screen (OBS, Discord, the browser) gets Island's picker (SharePicker.qml).
# Prints "[SELECTION]r/screen:NAME" or "[SELECTION]r/window:ID"; prints nothing when cancelled.
# Also leaves "pick" / "cancel" in island-share/result for tools/obsctl.py.
d="${XDG_RUNTIME_DIR:-/tmp}/island-share"; mkdir -p "$d"; rm -f "$d/answer"
printf '%s' "$XDPH_WINDOW_SHARING_LIST" > "$d/windows"
qs -c island ipc call island sharePick "$d/windows" >/dev/null 2>&1 || exec hyprland-share-picker   # Island not running
i=0; while [ ! -s "$d/answer" ] && [ $i -lt 1800 ]; do sleep 0.1; i=$((i + 1)); done
a=$(cat "$d/answer" 2>/dev/null)
if [ -n "$a" ] && [ "$a" != cancel ]; then echo pick > "$d/result"; echo "[SELECTION]r/$a"
else echo cancel > "$d/result"; fi
