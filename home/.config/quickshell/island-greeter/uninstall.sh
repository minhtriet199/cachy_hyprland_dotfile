#!/bin/sh
# Go back to the greetd config from before the Island login screen (auto-login + Island lock screen). Run:  sudo ./uninstall.sh
set -eu
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
if [ -f /etc/greetd/config.toml.before-island ]; then
    cp -a /etc/greetd/config.toml.before-island /etc/greetd/config.toml
    echo "greetd config restored. The files in /usr/local/share/island-greeter and /var/lib/island-greeter are kept (harmless)."
    echo "Reboot (or: sudo systemctl restart greetd — this ends your session) to use it."
else
    echo "no /etc/greetd/config.toml.before-island — nothing to restore"; exit 1
fi
