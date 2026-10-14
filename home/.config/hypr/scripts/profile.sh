#!/bin/sh
# Fn+F5: cycle ASUS profiles like Armoury Crate (Silent -> Performance -> Turbo).
# asusctl names: Quiet = Silent, Balanced = Performance, Performance = Turbo.
# Power limits and fan curves per profile are stored by asusd (profile tuning).
asusctl profile next >/dev/null 2>&1
sleep 0.3
case "$(cat /sys/firmware/acpi/platform_profile)" in
    quiet)       name="Silent";      body="35 W CPU · 70 W total · quiet fans" ;;
    balanced)    name="Performance"; body="65 W CPU · 100 W total · normal fans" ;;
    performance) name="Turbo";       body="80 W CPU · 115 W total · loud fans" ;;
    *)           name="$(cat /sys/firmware/acpi/platform_profile)"; body="" ;;
esac
notify-send -a "ASUS" -h string:x-canonical-private-synchronous:asus-profile \
    "Mode: $name" "$body"
