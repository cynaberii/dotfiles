#!/usr/bin/env bash
# (light/dark switch: wal-mode.sh light|dark|toggle, toggle by default. regenerates
# the palette in the chosen mode and runs postrun to reload everything.)
set -uo pipefail

WAL="$HOME/miniconda3/bin/wal"
WAL_CACHE="$HOME/.cache/wal"
MODE_FILE="$WAL_CACHE/appearance"
POSTRUN="$HOME/.config/wal/postrun"

current_mode() { [[ -f "$MODE_FILE" ]] && cat "$MODE_FILE" || echo dark; }

arg="${1:-toggle}"
case "$arg" in
  light|dark) target="$arg" ;;
  toggle)     [[ "$(current_mode)" == "light" ]] && target="dark" || target="light" ;;
  *) echo "usage: wal-mode.sh [light|dark|toggle]" >&2; exit 2 ;;
esac

WP=$(grep '^wallpaper=' "$WAL_CACHE/colors.sh" | cut -d'"' -f2)
if [[ -z "$WP" || ! -f "$WP" ]]; then
  echo "wal-mode: no current wallpaper in $WAL_CACHE/colors.sh" >&2
  exit 1
fi

# (-l = light, -n = keep the wallpaper. if/else not an array, macOS bash 3.2 trips
# on empty array expansion under set -u.)
if [[ "$target" == "light" ]]; then
  "$WAL" -i "$WP" --backend balanced -l -n -q
else
  "$WAL" -i "$WP" --backend balanced -n -q
fi

echo "$target" > "$MODE_FILE"
bash "$POSTRUN"
echo "appearance → $target"
