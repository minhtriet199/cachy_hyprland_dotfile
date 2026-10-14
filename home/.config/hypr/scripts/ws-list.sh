#!/bin/sh
# Super + Tab: list the workspaces on the monitor under the mouse (with their apps),
# pick one to switch to it. Uses the same numbering as ws.sh (laptop = 11-19, shown as 1-9).
command -v fuzzel >/dev/null || { noctalia msg window-switcher; exit 0; }

pos=$(hyprctl cursorpos); cx=${pos%%,*}; cy=${pos##*, }
mons=$(hyprctl monitors -j)
mon=$(echo "$mons" | jq -r --argjson x "$cx" --argjson y "$cy" '
    .[] | select($x >= .x and $x < .x + (.width / .scale)
             and $y >= .y and $y < .y + (.height / .scale)) | .name' | head -1)
active=$(echo "$mons" | jq -r --arg m "$mon" '.[] | select(.name == $m) | .activeWorkspace.id')
off=0; case "$mon" in eDP-*) off=10 ;; esac

list=$(hyprctl workspaces -j | jq -r --arg mon "$mon" --argjson off "$off" \
    --argjson act "$active" --argjson c "$(hyprctl clients -j)" '
    [ .[] | select(.monitor == $mon and .id > 0) ] | sort_by(.id)[] as $w
    | ($c | map(select(.workspace.id == $w.id) | .class | split(".") | last) | unique | join(", ")) as $apps
    | "\($w.id - $off)  \(if $w.id == $act then "●" else " " end)  \(if $apps == "" then "(empty)" else $apps end)"')

choice=$(printf '%s\n' "$list" | fuzzel --dmenu --prompt "Workspace  " --lines 9 --width 40) || exit 0
n=${choice%% *}
[ -n "$n" ] && ~/.config/hypr/scripts/ws.sh go "$n"
