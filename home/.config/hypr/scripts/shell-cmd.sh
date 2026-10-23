#!/bin/sh
# Shell-independent keybind helper.
# Usage: shell-cmd.sh <noctalia msg args...>   e.g.  shell-cmd.sh panel-toggle launcher
# Noctalia running -> passes the exact same command to "noctalia msg" (old behaviour).
# Island (Quickshell) running instead -> does the same job through Island or plain tools.

# Super+Tab: Island's Islands screen, or the old fuzzel workspace list under Noctalia
if [ "$1" = islands ]; then
    pgrep -x noctalia >/dev/null && exec "$HOME/.config/hypr/scripts/ws-list.sh"
    exec qs -c island ipc call island phone islands
fi

if pgrep -x noctalia >/dev/null; then
    exec noctalia msg "$@"
fi

island() { qs -c island ipc call island "$@"; }
notify() { notify-send -a "Shortcuts" "$1" "$2"; }

case "$*" in
    "panel-toggle launcher")                island phone search ;;
    "panel-toggle launcher /emo")           notify "Emoji picker" "Only in Noctalia for now" ;;
    "panel-toggle session")                 island power ;;
    "settings-toggle")                      island phone settings ;;
    "bar-toggle")                           island bar ;;
    "panel-toggle control-center bluetooth") island phone quick ;;
    "panel-toggle wallpaper")               island phone wallpapers ;;
    "panel-toggle clipboard")               island phone clipboard ;;
    "volume-up")                            wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
    "volume-down")                          wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    "volume-mute")                          wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    "mic-mute")                             wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
    "media toggle")                         playerctl play-pause ;;
    "media next")                           playerctl next ;;
    "media previous")                       playerctl previous ;;
    "brightness-up")                        brightnessctl -q set 5%+ ;;
    "brightness-down")                      brightnessctl -q set 5%- ;;
    "screenshot-region")                    exec "$HOME/.config/hypr/scripts/snip.sh" ;;
    "screenshot-fullscreen")
        dir="$HOME/Pictures/screenshot"; mkdir -p "$dir"
        file="$dir/full-$(date +%Y%m%d-%H%M%S).png"
        grim "$file" && wl-copy --type image/png < "$file" && notify-send -a "Screenshot" -i "$file" "Screenshot copied" "$file" ;;
    *) notify "Unknown shortcut" "$*" ;;
esac
