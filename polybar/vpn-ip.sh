#!/usr/bin/env bash

VPN_IFACES=("tun0" "wg0" "breachad" "enumad")

for iface in "${VPN_IFACES[@]}"; do
    if ip addr show "$iface" &>/dev/null; then
        IP=$(ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
        if [ -n "$IP" ]; then
            echo "󰖩 $IP"
            exit 0
        fi
    fi
done

# Disconnected

echo ""

