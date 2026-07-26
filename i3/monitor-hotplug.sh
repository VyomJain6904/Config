#!/usr/bin/env bash

set -euo pipefail

INTERNAL_OUTPUT="eDP"
EXTERNAL_OUTPUT="HDMI-A-0"
KERNEL_CONNECTOR="card0-HDMI-A-1"
STATUS_FILE="/sys/class/drm/$KERNEL_CONNECTOR/status"
LOG_FILE="/tmp/i3-monitor-hotplug-action.log"

exec >>"$LOG_FILE" 2>&1
printf '[%s] action=%s\n' "$(date '+%F %T')" "${1:-missing}"

apply_laptop_only() {
    xrandr \
        --output "$EXTERNAL_OUTPUT" --off \
        --output "$INTERNAL_OUTPUT" --auto --primary
}

apply_dual_layout() {
    xrandr \
        --output "$INTERNAL_OUTPUT" --auto --primary \
        --output "$EXTERNAL_OUTPUT" --auto --right-of "$INTERNAL_OUTPUT"
}

move_workspaces_to_internal() {
    local current_workspace
    current_workspace="$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused).name')"

    i3-msg -t get_workspaces \
        | jq -r --arg output "$EXTERNAL_OUTPUT" '.[] | select(.output == $output) | .name' \
        | while IFS= read -r workspace; do
            [ -n "$workspace" ] || continue
            i3-msg "workspace \"$workspace\"; move workspace to output $INTERNAL_OUTPUT" >/dev/null
        done

    if [ -n "$current_workspace" ]; then
        i3-msg "workspace \"$current_workspace\"" >/dev/null
    fi
}

restore_default_workspaces() {
    i3-msg "workspace number 1; move workspace to output $INTERNAL_OUTPUT" >/dev/null
    i3-msg "workspace number 2; move workspace to output $EXTERNAL_OUTPUT" >/dev/null
    i3-msg "workspace number 1" >/dev/null
}

current_mode() {
    local status
    status="$(cat "$STATUS_FILE" 2>/dev/null || true)"

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

case "${1:-}" in
    connect)
        printf '[%s] applying dual-monitor layout\n' "$(date '+%F %T')"
        apply_dual_layout
        restore_default_workspaces
        ;;
    disconnect)
        printf '[%s] applying laptop-only layout\n' "$(date '+%F %T')"
        apply_laptop_only
        sleep 1
        move_workspaces_to_internal
        ;;
    reconcile)
        mode="$(current_mode)"
        printf '[%s] reconciled kernel mode=%s\n' "$(date '+%F %T')" "$mode"
        case "$mode" in
            connect)
                printf '[%s] applying dual-monitor layout\n' "$(date '+%F %T')"
                apply_dual_layout
                restore_default_workspaces
                ;;
            disconnect)
                printf '[%s] applying laptop-only layout\n' "$(date '+%F %T')"
                apply_laptop_only
                sleep 1
                move_workspaces_to_internal
                ;;
            *)
                printf '[%s] no action for unknown connector state\n' "$(date '+%F %T')"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "usage: $0 {connect|disconnect|reconcile}" >&2
        exit 2
        ;;
esac

printf '[%s] action complete=%s\n' "$(date '+%F %T')" "$1"
