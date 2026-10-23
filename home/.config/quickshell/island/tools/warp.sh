#!/bin/sh
# Cloudflare WARP on demand: the warp-svc service (≈110 MB) only runs while WARP is on.
#   warp.sh on   start the service if needed, wait for it, register (first time only), connect, show its tray icon
#   warp.sh off  disconnect, close the tray icon, then stop the service
# Starting/stopping warp-svc without a password needs tools/warp-ondemand-setup.sh (polkit rule, run once with sudo).
case "$1" in
on)
    systemctl is-active -q warp-svc || systemctl start warp-svc || exit 1
    i=0
    until warp-cli --accept-tos status >/dev/null 2>&1; do
        i=$((i + 1)); [ "$i" -gt 40 ] && exit 1; sleep 0.25
    done
    warp-cli --accept-tos registration show >/dev/null 2>&1 || warp-cli --accept-tos registration new >/dev/null || exit 1   # first time
    warp-cli --accept-tos connect
    pgrep -x warp-taskbar >/dev/null || setsid -f warp-taskbar >/dev/null 2>&1   # its tray icon in the bar
    ;;
off)
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    pkill -x warp-taskbar
    systemctl is-enabled -q warp-svc 2>/dev/null || systemctl stop warp-svc
    ;;
*) echo "usage: warp.sh on|off" >&2; exit 2 ;;
esac
