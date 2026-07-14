#!/usr/bin/env bash

options="Lock\0icon\x1fsystem-lock-screen\nLogout\0icon\x1fxfsm-logout\nReboot\0icon\x1fxfsm-reboot\nShutdown\0icon\x1fsystem-shutdown"

chosen=$(echo -e "$options" | rofi -dmenu -theme ~/.config/rofi/powermenu.rasi)

case $chosen in
    "Lock")
        i3lock
        ;;
    "Logout")
        i3-msg exit
        ;;
    "Reboot")
        systemctl reboot
        ;;
    "Shutdown")
        systemctl poweroff
        ;;
esac
