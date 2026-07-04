#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"

IDLE=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $7}' | tr -d '%')
CPU=$(python3 -c "print(f'{100 - $IDLE:.0f}%')")

sketchybar --set "$NAME" icon.color=$WHITE label="$CPU" label.color=$WHITE
