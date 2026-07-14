#!/bin/bash

AC_STATUS=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)

if [ "$AC_STATUS" = "1" ]; then
    # AC power (charging) - disable all screen blanking/DPMS/suspend
    xset s off
    xset -dpms
    xset s noblank
    gsettings set org.gnome.desktop.session idle-delay 0
    gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
    gsettings set org.gnome.desktop.screensaver lock-enabled false
else
    # Battery - enable with 30 min idle delay
    xset s on
    xset +dpms
    xset s blank
    gsettings set org.gnome.desktop.session idle-delay 1800
    gsettings set org.gnome.desktop.screensaver idle-activation-enabled true
    gsettings set org.gnome.desktop.screensaver lock-enabled true
fi
