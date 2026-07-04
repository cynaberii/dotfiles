#!/usr/bin/env bash
# (rift version of plugins/workspacepeek_watch.sh. rift has no focus-changed event,
# so poll and fire triggers when the focused workspace or window changes. covers
# focus-follows-mouse and any out-of-band change.)
RIFT=/opt/homebrew/bin/rift-cli
JQ=/opt/homebrew/bin/jq
SKETCHYBAR=/opt/homebrew/bin/sketchybar
LAST_WS=""
LAST_FOC=""
LAST_ORDER=""

# (adaptive cadence: same-app window switches are only caught here, so poll fast
# while there's activity and relax to idle after a quiet stretch.)
FAST=0.08
IDLE=0.2
INTERVAL=$FAST
IDLE_TICKS=0

# (timeout, this polls forever so a blocked rift call can't hang it)
rq() { perl -e 'alarm shift; exec @ARGV' 3 "$RIFT" "$@"; }

while true; do
  JSON=$(rq query workspaces 2>/dev/null)
  if [[ -n "$JSON" ]]; then
    # (one jq pass emits "<active ws>\t<focused win id>\t<spatial order csv>". spatial
    # order = window ids left-to-right then top-to-bottom, so it changes on move/add/remove.)
    IFS=$'\t' read -r CUR_WS CUR_FOC CUR_ORDER < <(echo "$JSON" | $JQ -r '
      .[] | select(.is_active) |
      (.name) as $ws |
      ((.windows | map(select(.is_focused)) | .[0].window_server_id) // "" | tostring) as $foc |
      (.windows | sort_by(.frame.origin.x, .frame.origin.y) | map(.window_server_id | tostring) | join(",")) as $order |
      "\($ws)\t\($foc)\t\($order)"')
    CHANGED=0
    if [[ -n "$CUR_WS" && "$CUR_WS" != "$LAST_WS" ]]; then
      LAST_WS="$CUR_WS"
      $SKETCHYBAR --trigger rift_workspace_change
      CHANGED=1
    fi
    if [[ "$CUR_ORDER" != "$LAST_ORDER" ]]; then
      LAST_ORDER="$CUR_ORDER"
      $SKETCHYBAR --trigger rift_workspace_change
      CHANGED=1
    fi
    if [[ "$CUR_FOC" != "$LAST_FOC" ]]; then
      LAST_FOC="$CUR_FOC"
      $SKETCHYBAR --trigger rift_focus_change
      CHANGED=1
    fi
    if [[ "$CHANGED" -eq 1 ]]; then
      INTERVAL=$FAST; IDLE_TICKS=0
    else
      IDLE_TICKS=$((IDLE_TICKS + 1))
      [[ "$IDLE_TICKS" -ge 12 ]] && INTERVAL=$IDLE
    fi
  fi
  sleep "$INTERVAL"
done
