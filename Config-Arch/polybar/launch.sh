#!/bin/bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch Polybar, using default config location ~/.config/polybar/config
polybar main --config=~/.config/polybar/config.ini &
# polybar main --config=~/.config/polybar/config_new.ini  &

# Start control center daemon for instant toggle
pkill -f "control-center.py --daemon" 2>/dev/null
/usr/bin/python3 ~/.config/polybar/scripts/control-center.py --daemon >/dev/null 2>&1 &

# Build Go fast-metrics helper if available
CC_FAST_BIN="$HOME/.config/polybar/scripts/go/bin/cc-fast"
if command -v go >/dev/null 2>&1; then
  if [ ! -x "$CC_FAST_BIN" ]; then
    mkdir -p "$HOME/.config/polybar/scripts/go/bin"
    (cd "$HOME/.config/polybar/scripts/go" && go build -o "$CC_FAST_BIN" ./cmd/cc-fast) >/dev/null 2>&1
  fi
fi

echo "Polybar launched..."
