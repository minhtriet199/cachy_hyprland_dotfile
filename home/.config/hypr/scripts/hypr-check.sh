#!/bin/sh
# Health check for the Hyprland + Island setup (read-only: changes nothing).
#   hypr-check.sh          full report, exit 1 when something is wrong (also run after "sudo pacman -Syu" from Island)
#   hypr-check.sh login    at login (autostart.lua): runs only when Hyprland's version changed since the last login,
#                          and sends a notification if something is wrong
# Checks: Lua syntax of every config file, Hyprland --verify-config, hyprctl configerrors, Python syntax of the scripts/tools,
# the tools the scripts need (and whether an orphan cleanup could remove them — that's how jq vanished once).
H=$HOME/.config/hypr
I=$HOME/.config/quickshell/island
VERFILE=$HOME/.local/state/hypr/last-version
ver=$(hyprctl version -j 2>/dev/null | sed -n 's/.*"tag": *"\([^"]*\)".*/\1/p' | head -1)
last=$(cat "$VERFILE" 2>/dev/null)
if [ "$1" = login ]; then
    [ -n "$ver" ] && [ "$ver" = "$last" ] && exit 0
fi
bad=""
say() { bad="$bad$1
"; }

for f in "$H"/hyprland.lua "$H"/config/*.lua; do
    out=$(luac -p "$f" 2>&1) || say "Lua: $out"
done
out=$(Hyprland --verify-config -c "$H/hyprland.lua" 2>&1 | sed -n '/Config parsing result/,$p' | sed '1d;/^$/d')
[ "$out" = "config ok" ] || say "verify-config: $out"
err=$(hyprctl configerrors 2>&1)
[ -n "$err" ] && [ "$err" != "no errors" ] && say "configerrors: $err"
for f in "$H"/scripts/*.py "$I"/tools/*.py; do
    out=$(python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$f" 2>&1) || say "Python: ${f#$HOME/}: $(echo "$out" | tail -1)"
done
deps=$(pacman -Qdq 2>/dev/null)
for t in jq nmcli brightnessctl hyprsunset wl-paste wl-copy notify-send hyprlock wpctl ddcutil asusctl bluetoothctl \
         hyprpicker grim slurp playerctl luac qs kitty; do
    p=$(command -v "$t") || { say "missing tool: $t"; continue; }
    pkg=$(pacman -Qqo "$p" 2>/dev/null)
    [ -n "$pkg" ] && echo "$deps" | grep -qx "$pkg" && say "$t ($pkg) is installed only as a dependency — an orphan cleanup could remove it: sudo pacman -D --asexplicit $pkg"
done

[ -n "$ver" ] && [ "$ver" != "$last" ] && head="Hyprland ${last:-?} → $ver. " || head=""
if [ -z "$bad" ]; then
    [ -n "$ver" ] && mkdir -p "${VERFILE%/*}" && echo "$ver" > "$VERFILE"
    [ "$1" = login ] && [ -n "$head" ] && notify-send -a Island "Setup check passed" "${head}No problems found."
    [ "$1" = login ] || echo "${head}All checks passed."
    exit 0
fi
# a failed check keeps the old version recorded, so the next login checks again
if [ "$1" = login ]; then
    notify-send -a Island -u critical "Setup check found problems" "${head}Run ~/.config/hypr/scripts/hypr-check.sh in a terminal.
$(printf %s "$bad" | head -3)"
else
    [ -n "$head" ] && echo "$head"
    printf '%s' "$bad"
fi
exit 1
