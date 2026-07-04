#!/usr/bin/env bash
# (rift version of items/spaces.sh. rift has 9 fixed workspaces so make pills 1..9
# unconditionally, works even before rift is running. pill N == rift index N-1.)
source "$HOME/.cache/wal/colors-sketchybar.sh"
RIFT=/opt/homebrew/bin/rift-cli

for sid in 1 2 3 4 5 6 7 8 9; do
  idx=$((sid - 1))
  sketchybar --add item space."$sid" left \
    --subscribe space."$sid" rift_workspace_change \
    --set space."$sid" \
      icon="$sid" \
      icon.align=center \
      label="" \
      label.drawing=off \
      icon.color=$BLACK \
      background.color=$DIM \
      background.corner_radius=5 \
      background.height=25 \
      background.drawing=on \
      icon.padding_left=10 \
      icon.padding_right=5 \
      width=30 \
      click_script="$RIFT execute workspace switch $idx && sketchybar --trigger rift_workspace_change" \
      script="$PLUGIN_DIR/rift.sh"
done
