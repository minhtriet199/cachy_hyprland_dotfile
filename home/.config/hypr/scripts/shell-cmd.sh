#!/bin/sh
# Shell-independent keybind helper.
# Usage: shell-cmd.sh <noctalia msg args...>   e.g.  shell-cmd.sh panel-toggle launcher
# Noctalia running -> passes the exact same command to "noctalia msg" (old behaviour).
# Isla (Quickshell) running instead -> does the same job through Isla or plain tools.

if pgrep -x noctalia >/dev/null; then
    exec noctalia msg "$@"
fi

isla() { qs -c isla ipc call isla "$@"; }
notify() { notify-send -a "Shortcuts" "$1" "$2"; }

power_menu() {
    choice=$(printf 'Log out\nSuspend\nReboot\nShut down\n' | fuzzel --dmenu --prompt 'Power: ' --lines 4) || exit 0
    case "$choice" in
        "Log out")   uwsm stop ;;
        "Suspend")   systemctl suspend ;;
        "Reboot")    systemctl reboot ;;
        "Shut down") systemctl poweroff ;;
    esac
}

case "$*" in
    "panel-toggle launcher")                isla phone search ;;
    "panel-toggle launcher /emo")           notify "Emoji picker" "Only in Noctalia for now" ;;
    "panel-toggle session")                 power_menu ;;
    "settings-toggle")                      isla phone settings ;;
    "bar-toggle")                           isla bar ;;
    "panel-toggle control-center bluetooth") isla phone quick ;;
    "panel-toggle wallpaper")               isla phone wallpapers ;;
    "panel-toggle clipboard")               cliphist list | fuzzel --dmenu --prompt 'Clipboard: ' | cliphist decode | wl-copy ;;
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
