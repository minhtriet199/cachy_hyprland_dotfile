#!/bin/sh
# Privileged helper for the file-sharing toggle (run as root via sudo).
# Opens/closes LAN file-sharing ports (LocalSend + KDE Connect) in the RUNTIME firewall only,
# so a reboot or `firewall-cmd --reload` returns you to locked-down. Auto-closes after 15 min.
# Prints "on" or "off".
PORTS="53317/tcp 53317/udp 1714-1764/tcp 1714-1764/udp"
AUTO=share-firewall-autooff

close() {
    for p in $PORTS; do firewall-cmd --remove-port=$p >/dev/null 2>&1; done
    systemctl stop $AUTO.timer >/dev/null 2>&1
    systemctl reset-failed $AUTO.service >/dev/null 2>&1
    echo off
}
open() {
    for p in $PORTS; do firewall-cmd --add-port=$p >/dev/null; done
    systemctl stop $AUTO.timer >/dev/null 2>&1
    systemd-run --unit=$AUTO --on-active=15min --timer-property=AccuracySec=10s \
        /bin/sh -c "for p in $PORTS; do firewall-cmd --remove-port=\$p >/dev/null 2>&1; done" >/dev/null 2>&1
    echo on
}

case "$1" in
    on)  open ;;
    off) close ;;
    *)   firewall-cmd --query-port=53317/tcp >/dev/null 2>&1 && close || open ;;
esac
