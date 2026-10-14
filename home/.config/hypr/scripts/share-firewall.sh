#!/bin/sh
# File-sharing toggle (launcher button). Opens a small terminal to ask for your password,
# then opens LAN file-sharing ports for 15 minutes (or closes them if already open).
dir=$(dirname "$0")
exec kitty --title "File sharing" --class share-firewall sh -c '
    echo "Opening/closing LAN file-sharing ports in the firewall."
    S=$(sudo '"$dir"'/share-firewall-root.sh toggle)
    case "$S" in
        on)  notify-send -a Firewall -i network-transmit-receive "File sharing ON" "LocalSend / KDE Connect can reach this laptop for 15 minutes.";
             echo; echo "OPEN for 15 minutes. Run again to close now." ;;
        off) notify-send -a Firewall -i network-offline "File sharing off" "Sharing ports closed.";
             echo; echo "Closed." ;;
        *)   notify-send -a Firewall "File sharing" "Firewall not set up yet?"; echo "Nothing changed." ;;
    esac
    sleep 2'
