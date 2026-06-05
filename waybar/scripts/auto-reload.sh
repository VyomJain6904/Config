#!/bin/bash

while inotifywait -r -e close_write,moved_to --exclude '\.git' ~/.config/waybar; do
  killall -SIGUSR2 waybar
done
