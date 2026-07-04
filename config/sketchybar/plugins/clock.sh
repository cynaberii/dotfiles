#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"
sketchybar --set "$NAME" icon="󱑂" icon.color=$WHITE label.color=$WHITE label="$(date '+%a, %d %b | %H:%M')"
