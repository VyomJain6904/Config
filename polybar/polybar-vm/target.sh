#!/usr/bin/env bash

TARGET_FILE="$HOME/.cache/target_ip"

if [[ -f "$TARGET_FILE" ]]; then
    TARGET=$(cat "$TARGET_FILE")
    echo " $TARGET"
else
    echo ""
fi

