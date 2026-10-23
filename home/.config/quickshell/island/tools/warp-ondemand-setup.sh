#!/bin/sh
# One-time setup for WARP on demand (run:  sudo ./warp-ondemand-setup.sh   ·  undo:  sudo ./warp-ondemand-setup.sh undo)
# 1. polkit rule: your user may start/stop warp-svc.service without a password (nothing else)
# 2. warp-svc no longer starts at boot; Island's WARP button starts it when you turn WARP on
set -eu
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0 $*"; exit 1; }
user="${SUDO_USER:?run with sudo from your own account}"
rule=/etc/polkit-1/rules.d/50-island-warp.rules
if [ "${1:-}" = undo ]; then
    rm -f "$rule"; systemctl enable --now warp-svc
    echo "Undone: warp-svc starts at boot again, polkit rule removed."; exit 0
fi
cat > "$rule" <<RULE
// Island rice: $user may start/stop Cloudflare WARP's service without a password (tools/warp.sh)
polkit.addRule(function (action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "warp-svc.service" &&
        (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
        subject.user == "$user" && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
RULE
chmod 644 "$rule"
systemctl disable --now warp-svc
echo "Done: warp-svc is off and won't start at boot. Turn WARP on from Island (Quick panel) when you need it."
