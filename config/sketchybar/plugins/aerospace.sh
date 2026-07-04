#!/usr/bin/env bash
# (workspace pills: show the focused + any non-empty workspace, hide empty ones.
# one `list-workspaces --empty no` call instead of a per-workspace loop.)
source "$HOME/.cache/wal/colors-sketchybar.sh"
AEROSPACE=/opt/homebrew/bin/aerospace

# (timeout, aerospace's CLI can block forever when the server is busy)
asp() { perl -e 'alarm shift; exec @ARGV' 3 "$AEROSPACE" "$@"; }

FOCUSED=$(asp list-workspaces --focused --format "%{workspace}")

declare -A NONEMPTY
for sid in $(asp list-workspaces --monitor all --empty no 2>/dev/null); do
  NONEMPTY[$sid]=1
done

BATCH=""
for sid in $(asp list-workspaces --all --format "%{workspace}"); do
  if [ "$sid" = "$FOCUSED" ]; then
    BATCH="$BATCH --set space.$sid background.color=$GREEN icon.color=$BLACK label.drawing=off drawing=on"
  elif [ -n "${NONEMPTY[$sid]}" ]; then
    BATCH="$BATCH --set space.$sid background.color=$DIM icon.color=$GREEN label.drawing=off drawing=on"
  else
    BATCH="$BATCH --set space.$sid drawing=off"
  fi
done

[[ -n "$BATCH" ]] && eval sketchybar $BATCH
