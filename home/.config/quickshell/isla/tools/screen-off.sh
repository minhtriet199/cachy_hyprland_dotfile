#!/bin/sh
# Isla idle timer: turn the screens off (DPMS). Moving the mouse / a key wakes them (Hyprland default).
# Tries both Lua call forms and checks the result, since a wrong form is silently accepted.
on() { hyprctl -j monitors | grep -q '"dpmsStatus": true'; }
hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null; sleep 0.8
on && { hyprctl dispatch 'hl.dsp.dpms("off")' >/dev/null; sleep 0.8; }
on && hyprctl dispatch 'hl.dsp.dpms({ "off" })' >/dev/null
exit 0
