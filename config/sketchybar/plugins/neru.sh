#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"

# (Neru keyboard-nav daemon state. lit when running, dim when off. polled, and
# bumped instantly by the Alt+Shift+N toggle.)
if /usr/bin/pgrep -x neru >/dev/null 2>&1; then
  sketchybar --set "$NAME" icon="󰉁" icon.color=$WHITE label="Neru" label.color=$WHITE
else
  sketchybar --set "$NAME" icon="󰉁" icon.color=$DIM label="Neru" label.color=$DIM
fi
