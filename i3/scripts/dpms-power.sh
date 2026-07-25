#!/bin/sh
# Disable screen blanking when on AC power, enable when on battery.
# Reads /sys/class/power_supply/ACAD/online (1=plugged, 0=battery).

ac_online=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)

if [ "$ac_online" = "1" ]; then
    xset s off
    xset dpms 0 0 0
else
    xset s on
    xset s 600 600
    xset dpms 600 600 600
fi
