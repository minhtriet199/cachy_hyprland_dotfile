#!/bin/sh
# Island "Sleep": hibernate (saved to disk, 0 W) when it's set up. Never suspend: this laptop doesn't wake from
# suspend (s2idle, found 2026-10-24) — until hibernate works it only turns the screens off (Island locks first).
LOG="$HOME/.local/state/island/power.log"
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
sleep 2
if [ "$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null)" = 's "yes"' ]; then
    log "hibernate"
    systemctl hibernate && exit 0
    log "hibernate failed → screens off"
else
    log "hibernate not set up yet → screens off"
fi
exec sh "$(dirname "$0")/screen-off.sh"
