#!/usr/bin/env bash

WIFI_IFACES=("eth0" "wlan0" "enp0s3")

for iface in "${WIFI_IFACES[@]}"; do
    if ip addr show "$iface" &>/dev/null; then
        IP=$(ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
        if [ -n "$IP" ]; then
            echo "󰖩 $IP"
            exit 0
        fi
    fi
done

echo "󰖂 NO WIFI"

