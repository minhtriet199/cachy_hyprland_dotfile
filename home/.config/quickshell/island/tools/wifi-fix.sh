#!/bin/sh
# Wi-Fi card stuck after booting Windows (MT7922 "firmware own failed"): unload the driver,
# drop the card off the PCI bus and rescan, so it starts fresh. Runs in kitty (asks for sudo).
dev=$(lspci -D -d 14c3: 2>/dev/null | awk '/Network/ { print $1; exit }')
[ -n "$dev" ] || { echo "No MediaTek Wi-Fi card found on the PCI bus."; exit 1; }
echo "== Driver log (this boot)"; journalctl -k -b | grep mt7921e | tail -3; echo
echo "== Resetting $dev"
sudo sh -c "modprobe -r mt7921e; echo 1 > /sys/bus/pci/devices/$dev/remove; sleep 1; echo 1 > /sys/bus/pci/rescan" || exit 1
i=0; until nmcli -t -f TYPE dev | grep -qx wifi; do i=$((i + 1)); [ "$i" -gt 10 ] && break; sleep 1; done
nmcli radio wifi on; echo
if nmcli -t -f TYPE dev | grep -qx wifi; then echo "✓ Wi-Fi is back"
else echo "✗ Still stuck — shut down fully, unplug the charger, wait 30 s, then boot."
     journalctl -k -b | grep mt7921e | tail -2; fi
