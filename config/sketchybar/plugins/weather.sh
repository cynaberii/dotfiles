#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"

ISMC="$HOME/.local/bin/iSMC"
JQ="/opt/homebrew/bin/jq"
STATE="$HOME/.cache/sketchybar/temp_mode"
MODE=$(cat "$STATE" 2>/dev/null || echo "weather")

if [[ "$MODE" == "cpu" ]]; then
  # (cpu temp mode, iSMC CPU Die Max)
  TEMP=$("$ISMC" temp -o json 2>/dev/null | "$JQ" -r '."CPU Die Max".quantity' 2>/dev/null)
  if [[ -z "$TEMP" || "$TEMP" == "null" ]]; then
    sketchybar --set "$NAME" icon="󰈸" icon.color=$WHITE label="--" label.color=$WHITE
  else
    TEMP_R=$(printf '%.0f°C' "$TEMP")
    sketchybar --set "$NAME" icon="󰈸" icon.color=$WHITE label="$TEMP_R" label.color=$WHITE
  fi
  exit 0
fi

# (weather mode)
WEATHER=$(curl -sf "https://wttr.in/?format=%C+%t" 2>/dev/null)
if [[ -z "$WEATHER" ]]; then
  sketchybar --set "$NAME" icon="󰼯" icon.color=$WHITE label="--" label.color=$WHITE
  exit 0
fi
CONDITION=$(echo "$WEATHER" | sed 's/ [+-]*[0-9]*°.$//' | tr '[:upper:]' '[:lower:]')
TEMP=$(echo "$WEATHER" | grep -oE '[+-]?[0-9]+°.')
if [[ "$CONDITION" == *"sunny"* ]] || [[ "$CONDITION" == *"clear"* ]]; then ICON="󰖙"
elif [[ "$CONDITION" == *"partly"* ]] || [[ "$CONDITION" == *"cloudy"* ]]; then ICON="󰖕"
elif [[ "$CONDITION" == *"overcast"* ]]; then ICON="󰖐"
elif [[ "$CONDITION" == *"rain"* ]] || [[ "$CONDITION" == *"drizzle"* ]]; then ICON="󰖗"
elif [[ "$CONDITION" == *"thunder"* ]] || [[ "$CONDITION" == *"storm"* ]]; then ICON="󰖓"
elif [[ "$CONDITION" == *"snow"* ]] || [[ "$CONDITION" == *"blizzard"* ]]; then ICON="󰖘"
elif [[ "$CONDITION" == *"fog"* ]] || [[ "$CONDITION" == *"mist"* ]]; then ICON="󰖑"
else ICON="󰖔"
fi
sketchybar --set "$NAME" icon="$ICON" icon.color=$WHITE label="$TEMP" label.color=$WHITE
