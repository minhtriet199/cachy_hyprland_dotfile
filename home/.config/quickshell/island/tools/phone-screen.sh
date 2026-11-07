#!/bin/sh
# Phone Link "Show phone screen": the phone's screen in a window here, mouse + keyboard control it (scrcpy over
# Wi-Fi adb). Needs Wireless debugging on the phone (Developer options); Android turns it off after a Wi-Fi change.
# The PC is already paired for adb, so finding the phone (mDNS) and connecting is all this does.
say() { notify-send -a "Phone Link" -i phone "$1" "$2"; }
command -v scrcpy >/dev/null && command -v adb >/dev/null || { say "scrcpy isn't installed" "Run: sudo pacman -S scrcpy"; exit 1; }

# already open → bring it forward
win=$(hyprctl clients -j | jq -r '.[] | select(.class == "scrcpy") | .address' | head -n1)
[ -n "$win" ] && { hyprctl dispatch "hl.dsp.focus({ window = \"address:$win\" })" >/dev/null; exit 0; }

# the paired phone's name and Wi-Fi address (island-link-pc remembers them)
phones="${XDG_DATA_HOME:-$HOME/.local/share}/island-link/phones.json"
name=$(jq -r '.[0].name // "Phone"' "$phones" 2>/dev/null); name=${name:-Phone}
ip=$(jq -r '.[0].addr // empty' "$phones" 2>/dev/null)

serial=$(adb devices | awk 'NR > 1 && $2 == "device" && $1 ~ /:/ { print $1; exit }')
if [ -z "$serial" ]; then
    # Wireless debugging announces itself on the network; prefer the paired phone's address
    found=$(adb mdns services 2>/dev/null | awk '/_adb-tls-connect/ { print $NF }')
    addr=$( { [ -n "$ip" ] && echo "$found" | grep "^$ip:"; echo "$found"; } | head -n1)
    [ -z "$addr" ] && { say "Turn on Wireless debugging" "On $name: Settings → System → Developer options → Wireless debugging. Then tap Show phone screen again."; exit 1; }
    adb connect "$addr" | grep -q "connected to" || { say "Couldn't connect to $name" "adb connect $addr failed. Is it still paired? Developer options → Wireless debugging → Pair."; exit 1; }
    serial=$addr
fi

exec scrcpy -s "$serial" --window-title "$name" --shortcut-mod=lalt 2>/dev/null
