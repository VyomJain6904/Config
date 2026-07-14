#!/usr/bin/env bash

# Kill existing polybar instances
pkill polybar 2>/dev/null
sleep 0.5

# Kill existing bluetooth daemon
if [[ -f ~/.cache/polybar-bluetooth/daemon.pid ]]; then
    old_pid=$(cat ~/.cache/polybar-bluetooth/daemon.pid)
    kill "$old_pid" 2>/dev/null
    rm -f ~/.cache/polybar-bluetooth/daemon.pid
fi

# Launch polybar on each monitor
if type "xrandr" > /dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar --reload toph &
    done
else
    polybar --reload toph &
fi

# Fix G: Auto-start bluetooth daemon in background after polybar is up
sleep 0.5
~/.config/polybar/scripts/bluetooth-daemon &

# Auto-start wifi daemon in background
~/.config/polybar/scripts/wifi-daemon &
