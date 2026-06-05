#!/bin/bash

entries=("󰐥 Shutdown" "󰜉 Reboot" "󰍃 Log Out" "󰒲 Suspend")

chosen=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -theme ~/.config/rofi/spotlight.rasi -p "Power" -i)

case "$chosen" in
"󰐥 Shutdown") systemctl poweroff ;;
"󰜉 Reboot") systemctl reboot ;;
"󰍃 Log Out") hyprctl dispatch exit ;;
"󰒲 Suspend") systemctl suspend ;;
esac
