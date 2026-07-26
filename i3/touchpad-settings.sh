#!/usr/bin/env bash

set -euo pipefail

touchpad="$(xinput list --name-only | awk '/Touchpad/ { print; exit }')"
[ -n "$touchpad" ] || exit 0

xinput set-prop "$touchpad" "libinput Tapping Enabled" 1 2>/dev/null || true
xinput set-prop "$touchpad" "libinput Natural Scrolling Enabled" 1 2>/dev/null || true
