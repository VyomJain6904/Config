#!/usr/bin/env bash

set -euo pipefail

KERNEL_CONNECTOR="card0-HDMI-A-1"
ACTION_SCRIPT="$HOME/.config/i3/monitor-hotplug.sh"
LOCK_FILE="/tmp/i3-monitor-hotplug-listener.lock"
STATE_FILE="/tmp/i3-monitor-hotplug-listener.state"
LOG_FILE="/tmp/i3-monitor-hotplug-listener.log"

exec >>"$LOG_FILE" 2>&1
printf '[%s] listener start\n' "$(date '+%F %T')"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

connector_mode() {
    local status
    status="$(cat "/sys/class/drm/$KERNEL_CONNECTOR/status" 2>/dev/null || true)"
    case "$status" in
        connected)
            printf 'connect\n'
            ;;
        disconnected)
            printf 'disconnect\n'
            ;;
        *)
            printf 'unknown\n'
            ;;
    esac
}

apply_if_changed() {
    local mode last_mode

    mode="$(connector_mode)"
    last_mode="$(cat "$STATE_FILE" 2>/dev/null || true)"

    printf '[%s] observed mode=%s last_mode=%s\n' "$(date '+%F %T')" "$mode" "${last_mode:-unset}"

    case "$mode" in
        connect|disconnect)
            if [ "$mode" = "$last_mode" ]; then
                printf '[%s] skipping unchanged mode=%s\n' "$(date '+%F %T')" "$mode"
                return
            fi

            "$ACTION_SCRIPT" reconcile
            printf '%s\n' "$mode" > "$STATE_FILE"
            printf '[%s] stored mode=%s\n' "$(date '+%F %T')" "$mode"
            ;;
        *)
            printf '[%s] ignoring unknown connector state\n' "$(date '+%F %T')"
            ;;
    esac
}

apply_if_changed

udevadm monitor --udev --subsystem-match=drm | while IFS= read -r line; do
    printf '[%s] event=%s\n' "$(date '+%F %T')" "$line"

    case "$line" in
        *"$KERNEL_CONNECTOR"*|*"card0"*)
            apply_if_changed
            ;;
    esac
done
