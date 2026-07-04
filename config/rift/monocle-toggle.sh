#!/usr/bin/env bash
# (maximise the focused column to full width, press again to restore. rift has no
# maximise command and column_width_ratio only applies on layout build, so nudge
# the live width with resize-by.)
RIFT=/opt/homebrew/bin/rift-cli
JQ=/opt/homebrew/bin/jq
STATE=/tmp/rift-maximized-window

CFG=$("$RIFT" execute config get 2>/dev/null)
BASE=$(echo "$CFG" | "$JQ" -r '.settings.layout.scrolling.column_width_ratio // empty')
MAX=$(echo  "$CFG" | "$JQ" -r '.settings.layout.scrolling.max_column_width_ratio // empty')
BASE=${BASE:-0.5}
MAX=${MAX:-1.0}

JSON=$("$RIFT" query workspaces 2>/dev/null)
FOCUSED=$(echo "$JSON" | "$JQ" -r '.[] | select(.is_active) | .windows[] | select(.is_focused) | .window_server_id' | head -1)
PREV=$(cat "$STATE" 2>/dev/null)

if [[ -n "$FOCUSED" && "$FOCUSED" == "$PREV" ]]; then
  # (already maximised, shrink back to base. -- guards the minus.)
  DELTA=$(awk "BEGIN{printf \"%.4f\", -1*($MAX-$BASE)}")
  "$RIFT" execute window resize-by -- "$DELTA"
  rm -f "$STATE"
else
  "$RIFT" execute window resize-by -- "$MAX"
  echo "$FOCUSED" > "$STATE"
fi
