#!/bin/bash
USER_NAME=jain
DISPLAY_NUM=:0
USER_ID=$(id -u $USER_NAME)

export DISPLAY=$DISPLAY_NUM
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus
export XAUTHORITY=/home/$USER_NAME/.Xauthority

su $USER_NAME -c "/home/$USER_NAME/.config/i3/power-manager.sh"
