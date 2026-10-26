#!/bin/sh
# Super+Q: a Picture-in-Picture window is showing → hide it in special:pip (it keeps playing); hidden → bring it back
# to this workspace, pinned again; none → ask Helium to pop the playing video out (Google's "Picture-in-Picture
# Extension", its shortcut Alt+P, sent straight to the Helium window). Close a PiP with its own ✕.
pip=$(hyprctl -j clients | jq -r 'first(.[] | select(.title | test("^[Pp]icture[- ]?[Ii]n[- ]?[Pp]icture")) | "\(.address) \(.workspace.name)") // empty')
if [ -n "$pip" ]; then
    addr=${pip%% *} win="window = \"address:$addr\""
    if [ "${pip#* }" = special:pip ]; then
        ws=$(hyprctl -j activeworkspace | jq -r .id)
        hyprctl dispatch "hl.dsp.window.move({ workspace = $ws, $win, follow = false })" >/dev/null
        hyprctl dispatch "hl.dsp.window.pin({ action = \"enable\", $win })" >/dev/null
    else   # a pinned window can't change workspace
        hyprctl dispatch "hl.dsp.window.pin({ action = \"disable\", $win })" >/dev/null
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:pip\", $win, follow = false })" >/dev/null
    fi
    exit 0
fi
if ! hyprctl -j clients | jq -e 'any(.[]; .class == "helium")' >/dev/null; then
    notify-send -a "Picture-in-Picture" "No video to pop out" "Play a video in Helium first"; exit 0
fi
hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "ALT", key = "P", window = "class:^(helium)$" })' >/dev/null
