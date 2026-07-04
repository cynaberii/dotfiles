#!/usr/bin/env bash
# (rift version of plugins/windows_focus.sh. just recolours existing glyphs by
# focus, no add/remove.)
source "$HOME/.cache/wal/colors-sketchybar.sh"
RIFT=/opt/homebrew/bin/rift-cli
JQ=/opt/homebrew/bin/jq

rq() { perl -e 'alarm shift; exec @ARGV' 3 "$RIFT" "$@"; }

JSON=$(rq query workspaces 2>/dev/null)
[[ -z "$JSON" ]] && exit 0

BATCH=""
while IFS='|' read -r WIN_ID FOC; do
  [[ -z "$WIN_ID" || "$WIN_ID" == "null" ]] && continue
  if [[ "$FOC" == "true" ]]; then
    BATCH="$BATCH --set window.$WIN_ID background.color=$PINK icon.color=$BLACK label.color=$BLACK"
  else
    BATCH="$BATCH --set window.$WIN_ID background.color=$DIM icon.color=$WHITE label.color=$WHITE"
  fi
done < <(echo "$JSON" | $JQ -r \
  '.[] | select(.is_active) | .windows[] | "\(.window_server_id)|\(.is_focused)"')

[[ -n "$BATCH" ]] && eval sketchybar $BATCH
