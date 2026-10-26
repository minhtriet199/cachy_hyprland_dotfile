#!/bin/sh
# Wi-Fi page (WifiDetail.qml) → show password / share by QR. Only runs when you tap 👁 or Share.
#   wifi-share.sh CONNECTION SSID   → line 1: the password ("" for an open network)
#                                     line 2: the join QR as a PNG data URL (phones scan it to join), never written to disk
# Reading the password needs no root for your own saved networks (nmcli -s).
con=$1 ssid=$2
out=$(nmcli -s -g 802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless-security.wep-key0 connection show id "$con") || exit 1
km=$(printf '%s\n' "$out" | sed -n 1p); psk=$(printf '%s\n' "$out" | sed -n 2p); wep=$(printf '%s\n' "$out" | sed -n 3p)
case "$km" in
    "" | none) [ -n "$wep" ] && { t=WEP; pw=$wep; } || { t=nopass; pw=""; } ;;
    *) t=WPA; pw=$psk ;;          # wpa-psk and sae (WPA3) both join as "WPA"
esac
# WIFI: QR text — \ ; , : " in the name / password are escaped with a backslash
esc() { printf '%s' "$1" | sed 's/[\\;,:"]/\\&/g'; }
printf '%s\n' "$pw"
printf 'data:image/png;base64,'
if [ "$t" = nopass ]; then q="WIFI:T:nopass;S:$(esc "$ssid");;"; else q="WIFI:T:$t;S:$(esc "$ssid");P:$(esc "$pw");;"; fi
printf '%s' "$q" | qrencode -t PNG -s 8 -m 2 -o - | base64 -w 0
echo
