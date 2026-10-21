#!/bin/sh
# Super+Q: a Picture-in-Picture window is open → close it (from any app); otherwise ask Helium to pop the playing
# video out (Google's "Picture-in-Picture Extension", its shortcut Alt+P, sent straight to the Helium window).
pip=$(hyprctl -j clients | jq -r 'first(.[] | select(.title | test("^[Pp]icture[- ]?[Ii]n[- ]?[Pp]icture")) | .address) // empty')
if [ -n "$pip" ]; then
    prev=$(hyprctl -j activewindow | jq -r '.address // empty')
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$pip\" })" >/dev/null
    # close only if the PiP really got focus (close() acts on the focused window)
    [ "$(hyprctl -j activewindow | jq -r '.address // empty')" = "$pip" ] && hyprctl dispatch 'hl.dsp.window.close()' >/dev/null
    [ -n "$prev" ] && [ "$prev" != "$pip" ] && hyprctl dispatch "hl.dsp.focus({ window = \"address:$prev\" })" >/dev/null
    exit 0
fi
if ! hyprctl -j clients | jq -e 'any(.[]; .class == "helium")' >/dev/null; then
    notify-send -a "Picture-in-Picture" "No video to pop out" "Play a video in Helium first"; exit 0
fi
hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "ALT", key = "P", window = "class:^(helium)$" })' >/dev/null
