#!/bin/bash
# (toggle web-page recolouring, the matugen-bridge mod in zen. writes true/false to
# a state file the bridge polls every ~1s and re-themes open tabs.)
set -euo pipefail

STATE_FILE="$HOME/.cache/quickshell/custom_web_theme_state"
mkdir -p "$(dirname "$STATE_FILE")"

cur="true"
[ -f "$STATE_FILE" ] && cur="$(tr -d '[:space:]' < "$STATE_FILE")"

if [ "$cur" = "false" ]; then
  printf 'true' > "$STATE_FILE"; new="on"
else
  printf 'false' > "$STATE_FILE"; new="off"
fi

# (WalNotify HUD, same one the wallpaper/tab-unload toggles use. kill any lingering
# HUD first so quick presses don't stack.)
NOTIFY="$HOME/.local/bin/WalNotify"
pkill -x WalNotify 2>/dev/null || true
[ -x "$NOTIFY" ] && "$NOTIFY" --raw "୨୧ web theme ‧₊˚ $new ✧" >/dev/null 2>&1 &
disown 2>/dev/null || true

echo "web theme -> $new"
