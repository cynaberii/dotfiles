#!/usr/bin/env bash
STATE="$HOME/.cache/sketchybar/temp_mode"
mkdir -p "$(dirname "$STATE")"
current=$(cat "$STATE" 2>/dev/null || echo "weather")
if [[ "$current" == "weather" ]]; then
  echo "cpu" > "$STATE"
  sketchybar --set weather update_freq=2
else
  echo "weather" > "$STATE"
  sketchybar --set weather update_freq=1800
fi
"$HOME/.config/sketchybar/plugins/weather.sh"
