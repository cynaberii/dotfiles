#!/usr/bin/env bash
# (rift version of plugins/aerospace.sh. colours pills from rift-cli: focused =
# green bg / black icon, non-empty = dim bg / green icon, empty = hidden.)
source "$HOME/.cache/wal/colors-sketchybar.sh"
RIFT=/opt/homebrew/bin/rift-cli
JQ=/opt/homebrew/bin/jq

# (timeout so a blocked rift CLI can't pile up hung procs)
rq() { perl -e 'alarm shift; exec @ARGV' 3 "$RIFT" "$@"; }

JSON=$(rq query workspaces 2>/dev/null)
[[ -z "$JSON" ]] && exit 0   # (rift not running, leave pills as-is)

FOCUSED=$(echo "$JSON" | $JQ -r '.[] | select(.is_active) | .name')

declare -A NONEMPTY
while read -r n; do [[ -n "$n" ]] && NONEMPTY[$n]=1; done \
  < <(echo "$JSON" | $JQ -r '.[] | select(.window_count > 0) | .name')

BATCH=""
for sid in $(echo "$JSON" | $JQ -r '.[].name'); do
  if [ "$sid" = "$FOCUSED" ]; then
    BATCH="$BATCH --set space.$sid background.color=$GREEN icon.color=$BLACK label.drawing=off drawing=on"
  elif [ -n "${NONEMPTY[$sid]}" ]; then
    BATCH="$BATCH --set space.$sid background.color=$DIM icon.color=$GREEN label.drawing=off drawing=on"
  else
    BATCH="$BATCH --set space.$sid drawing=off"
  fi
done

[[ -n "$BATCH" ]] && eval sketchybar $BATCH
