#!/usr/bin/env bash
# (in-column height resize. rift has no height command, so set it via accessibility
# and let rift's on_window_resized hook absorb it, like a mouse drag.)
STEP=80
DIR="${1:-grow}"

SIZE=$(osascript -e 'tell application "System Events" to tell (first application process whose frontmost is true) to get size of front window' 2>/dev/null)
[[ -z "$SIZE" ]] && exit 0
W=$(echo "$SIZE" | cut -d',' -f1 | tr -d ' ')
H=$(echo "$SIZE" | cut -d',' -f2 | tr -d ' ')
[[ -z "$W" || -z "$H" ]] && exit 0

if [[ "$DIR" == "shrink" ]]; then
  NEWH=$(( H - STEP ))
else
  NEWH=$(( H + STEP ))
fi
(( NEWH < 100 )) && NEWH=100

osascript -e "tell application \"System Events\" to tell (first application process whose frontmost is true) to set size of front window to {$W, $NEWH}" 2>/dev/null
