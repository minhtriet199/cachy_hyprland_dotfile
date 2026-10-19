#!/bin/sh
# Cloudflare WARP on demand: the warp-svc service (≈110 MB) only runs while WARP is on.
#   warp.sh on   start the service if needed, wait for it, connect
#   warp.sh off  disconnect, then stop the service
# Starting/stopping warp-svc without a password needs tools/warp-ondemand-setup.sh (polkit rule, run once with sudo).
case "$1" in
on)
    systemctl is-active -q warp-svc || systemctl start warp-svc || exit 1
    i=0
    until warp-cli --accept-tos status >/dev/null 2>&1; do
        i=$((i + 1)); [ "$i" -gt 40 ] && exit 1; sleep 0.25
    done
    warp-cli --accept-tos connect
    ;;
off)
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    systemctl is-enabled -q warp-svc 2>/dev/null || systemctl stop warp-svc
    ;;
*) echo "usage: warp.sh on|off" >&2; exit 2 ;;
esac
