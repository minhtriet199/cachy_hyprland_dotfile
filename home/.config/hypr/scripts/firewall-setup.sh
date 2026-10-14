#!/bin/sh
# One-time firewalld setup for this laptop.  Run with:  sudo firewall-setup.sh
# Blocks incoming connections (public zone) but allows Steam Remote Play to your own devices.
# Outgoing traffic (browsing, games, downloads) is never touched.
set -e
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo $0" >&2; exit 1; }

firewall-cmd --set-default-zone=public

# Steam Remote Play / in-home streaming (e.g. to your Steam Deck) = your own trusted devices
firewall-cmd --permanent --delete-service=steam-remote-play 2>/dev/null || true
firewall-cmd --permanent --new-service=steam-remote-play
firewall-cmd --permanent --service=steam-remote-play --set-short="Steam Remote Play"
firewall-cmd --permanent --service=steam-remote-play --set-description="Steam Remote Play and in-home streaming to your own devices"
firewall-cmd --permanent --service=steam-remote-play --add-port=27031-27036/udp
firewall-cmd --permanent --service=steam-remote-play --add-port=27036-27037/tcp
firewall-cmd --permanent --add-service=steam-remote-play

firewall-cmd --reload
echo
echo "Firewall is ON (public zone)."
echo "  Allowed in : Steam Remote Play (your Steam Deck etc.)"
echo "  Blocked in : everything else uninvited"
echo "  Unaffected : all outgoing traffic (games, browsing, downloads)"
