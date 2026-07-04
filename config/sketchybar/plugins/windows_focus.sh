#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"
AEROSPACE=/opt/homebrew/bin/aerospace

# (timeout each call, aerospace's CLI can block forever and pile up hung procs)
asp() { perl -e 'alarm shift; exec @ARGV' 3 "$AEROSPACE" "$@"; }

FOCUSED_WINDOW=$(asp list-windows --focused --format "%{window-id}" 2>/dev/null)
FOCUSED_APP=$(asp list-windows --focused --format "%{app-name}" 2>/dev/null)
[[ "$FOCUSED_APP" == "Python" || "$FOCUSED_APP" == "python3" ]] && exit 0
FOCUSED_WORKSPACE=$(asp list-workspaces --focused --format "%{workspace}")
WINDOWS=$(asp list-windows --workspace "$FOCUSED_WORKSPACE" \
  --format "%{window-id}" 2>/dev/null)

BATCH=""
while IFS= read -r WIN_ID; do
  [[ -z "$WIN_ID" ]] && continue
  if [[ "$WIN_ID" = "$FOCUSED_WINDOW" ]]; then
    BATCH="$BATCH --set window.$WIN_ID background.color=$PINK icon.color=$BLACK label.color=$BLACK"
  else
    BATCH="$BATCH --set window.$WIN_ID background.color=$DIM icon.color=$WHITE label.color=$WHITE"
  fi
done <<< "$WINDOWS"

[[ -n "$BATCH" ]] && eval sketchybar $BATCH
