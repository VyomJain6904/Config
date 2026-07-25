#!/usr/bin/env bash

# This script monitors the AC adapter state via acpi_listen
# and dynamically toggles screen blanking (DPMS).

# Initial setup based on current state
if acpi -a | grep -q "on-line"; then
    xset -dpms
    xset s off
else
    xset +dpms
    xset s on
fi

# Listen for power events
acpi_listen | while read -r event; do
    if echo "$event" | grep -q "ac_adapter"; then
        if acpi -a | grep -q "on-line"; then
            # Plugged in: Never sleep, never turn black
            xset -dpms
            xset s off
        else
            # Unplugged: Restore normal screen saving
            xset +dpms
            xset s on
        fi
    fi
done
