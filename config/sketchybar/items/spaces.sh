#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"

# (timeout, aerospace's CLI can block forever when the server is busy)
asp() { perl -e 'alarm shift; exec @ARGV' 3 /opt/homebrew/bin/aerospace "$@"; }

for sid in $(asp list-workspaces --all --format "%{workspace}"); do
  sketchybar --add item space."$sid" left \
    --subscribe space."$sid" aerospace_workspace_change \
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
      click_script="aerospace workspace $sid && sketchybar --trigger aerospace_workspace_change" \
      script="$PLUGIN_DIR/aerospace.sh"
done
