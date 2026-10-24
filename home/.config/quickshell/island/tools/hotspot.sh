#!/bin/sh
# Hotspot: share this laptop's internet over Wi-Fi. NetworkManager connection "Island Hotspot" (mode ap, ipv4 shared =
# NAT + DHCP) on a second, virtual Wi-Fi interface (ap0) next to the normal one, so the laptop stays on its own Wi-Fi.
# The card can only use ONE channel at a time, so on Wi-Fi the hotspot follows the home network's channel and band;
# on a cable it uses the band you picked. Making ap0 needs root: the one-time helper (hotspot-if.src, NOPASSWD sudo)
# or else a password pop-up (pkexec, Island's polkit dialog).
#   status · on [auto|2.4|5] · off · set <name> <password>
C="Island Hotspot"; AP=ap0; HELPER=/usr/local/bin/island-hotspot-if
W=$(iw dev 2>/dev/null | awk '/Interface/{i=$2} /type managed/{print i; exit}')

have() { nmcli -t -f NAME con show 2>/dev/null | grep -qx "$C"; }
mkcon() {
    have && return 0
    pw=$(tr -dc 'a-km-z2-9' </dev/urandom | head -c 10)
    nmcli con add type wifi ifname $AP con-name "$C" autoconnect no ssid "$(cat /etc/hostname 2>/dev/null || echo Laptop) Hotspot" \
        mode ap ipv4.method shared ipv6.method ignore 802-11-wireless.cloned-mac-address stable \
        wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pw" >/dev/null
}
mkif() {
    if [ ! -e /sys/class/net/$AP ]; then
        if [ -x $HELPER ] && sudo -n $HELPER add 2>/dev/null; then :
        else pkexec iw dev "$W" interface add $AP type __ap || { echo "err=Couldn't make the hotspot interface (password cancelled?)"; exit 1; }; fi
    fi
    for _ in 1 2 3 4 5 6 7 8 9 10; do nmcli -t -f DEVICE dev 2>/dev/null | grep -qx $AP && break; sleep 0.3; done
    nmcli dev set $AP managed yes 2>/dev/null; nmcli dev set $AP autoconnect no 2>/dev/null
}

case "$1" in
status)
    have && nmcli -s -g 802-11-wireless.ssid,802-11-wireless-security.psk,802-11-wireless.band,802-11-wireless.channel con show "$C" 2>/dev/null \
        | { read -r n; read -r p; read -r b; read -r c; echo "name=$n"; echo "pass=$p"; echo "band=$b"; echo "chan=$c"; }
    nmcli -t -f NAME con show --active 2>/dev/null | grep -qx "$C" && echo on=1 || echo on=0
    [ -e /sys/class/net/$AP ] && echo "clients=$(iw dev $AP station dump 2>/dev/null | grep -c '^Station')"
    f=$(iw dev "$W" link 2>/dev/null | awk '/freq:/{print int($2)}'); echo "wifiFreq=$f"
    [ -x $HELPER ] && echo helper=1 || echo helper=0
    ;;
on)
    [ -n "$W" ] || { echo "err=No Wi-Fi card"; exit 1; }
    mkcon || { echo "err=Couldn't create the hotspot"; exit 1; }
    f=$(iw dev "$W" link 2>/dev/null | awk '/freq:/{print int($2)}')
    if [ -n "$f" ]; then                       # on Wi-Fi: same channel as the home network
        if [ "$f" -gt 5925 ]; then echo "err=Your Wi-Fi is on 6 GHz; the hotspot can't share that channel"; exit 1
        elif [ "$f" -gt 5000 ]; then band=a; ch=$(( (f - 5000) / 5 ))
        else band=bg; ch=$(( (f - 2407) / 5 )); fi
    else                                       # cable / no Wi-Fi: the band you picked, any channel
        case "$2" in 2.4) band=bg ;; *) band=a ;; esac; ch=0
    fi
    nmcli con mod "$C" 802-11-wireless.band $band 802-11-wireless.channel $ch || { echo "err=Couldn't set the channel"; exit 1; }
    mkif
    out=$(nmcli con up "$C" ifname $AP 2>&1) || { echo "err=$(echo "$out" | tail -1 | cut -c1-140)"; exit 1; }
    echo on=1
    ;;
off)
    nmcli con down "$C" >/dev/null 2>&1
    # with the helper ap0 goes away; without it (no second password) NM just stops using it until next time
    if [ -e /sys/class/net/$AP ]; then
        if [ -x $HELPER ]; then sudo -n $HELPER del 2>/dev/null; else nmcli dev set $AP managed no 2>/dev/null; fi
    fi
    echo on=0
    ;;
set)
    [ ${#3} -ge 8 ] || { echo "err=The password needs at least 8 characters"; exit 1; }
    mkcon && nmcli con mod "$C" 802-11-wireless.ssid "$2" wifi-sec.psk "$3" || { echo "err=Not saved"; exit 1; }
    nmcli -t -f NAME con show --active | grep -qx "$C" && nmcli con up "$C" ifname $AP >/dev/null 2>&1
    echo saved=1
    ;;
*) echo "usage: hotspot.sh status | on [auto|2.4|5] | off | set <name> <password>" >&2; exit 2 ;;
esac
