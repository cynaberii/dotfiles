#!/usr/bin/env bash
# (rift version of plugins/windows.sh. one glyph per window on the focused
# workspace, coloured by focus, ordered left-to-right by frame position. unlike the
# aerospace version these aren't click-to-focus, rift-cli has no focus-by-id.)
source "$HOME/.cache/wal/colors-sketchybar.sh"
RIFT=/opt/homebrew/bin/rift-cli
JQ=/opt/homebrew/bin/jq
source "$HOME/.config/sketchybar/icon_map.sh"

rq() { perl -e 'alarm shift; exec @ARGV' 3 "$RIFT" "$@"; }

# (single-instance guard, PID lockfile since macOS has no flock)
LOCK="/tmp/sketchybar-windows-rift.lock"
if [[ -f "$LOCK" ]] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

STATE="/tmp/sketchybar-window-items"

JSON=$(rq query workspaces 2>/dev/null)
[[ -z "$JSON" ]] && exit 0

# (active-workspace windows sorted left-to-right then top-to-bottom by frame. output: "id|app|is_focused")
WINS=$(echo "$JSON" | $JQ -r \
  '.[] | select(.is_active) | .windows
   | sort_by(.frame.origin.x, .frame.origin.y)
   | .[] | "\(.window_server_id)|\(.app_name)|\(.is_focused)"')

declare -A HAVE
if [[ -f "$STATE" ]]; then
  for id in $(<"$STATE"); do HAVE[$id]=1; done
fi

declare -A FOCUSED_SET
ORDER=()
BATCH=""

while IFS='|' read -r WIN_ID APP FOC; do
  [[ -z "$WIN_ID" || "$WIN_ID" == "null" ]] && continue
  [[ "$APP" == "Python" || "$APP" == "python3" ]] && continue
  FOCUSED_SET[$WIN_ID]=1
  ORDER+=("window.$WIN_ID")

  __icon_map "$APP"
  ICON=$icon_result

  if [[ "$FOC" == "true" ]]; then
    BG=$PINK; FG=$BLACK
  else
    BG=$DIM; FG=$GREEN
  fi

  if [[ -n "${HAVE[$WIN_ID]}" ]]; then
    BATCH="$BATCH --set window.$WIN_ID icon=$ICON label=\"$APP\" icon.color=$FG label.color=$FG background.color=$BG drawing=on"
  else
    BATCH="$BATCH \
      --add item window.$WIN_ID left \
      --set window.$WIN_ID \
        icon=$ICON \
        icon.color=$FG \
        icon.font=\"sketchybar-app-font:Regular:16.0\" \
        label=\"$APP\" \
        label.color=$FG \
        background.color=$BG \
        background.corner_radius=5 \
        background.height=25 \
        background.drawing=on \
        icon.padding_left=6 \
        icon.padding_right=2 \
        label.padding_left=2 \
        label.padding_right=8 \
        drawing=on"
  fi
done <<< "$WINS"

# (drop glyphs for windows no longer on the focused workspace)
for id in "${!HAVE[@]}"; do
  [[ -z "${FOCUSED_SET[$id]}" ]] && BATCH="$BATCH --remove window.$id"
done

[[ -n "$BATCH" ]] && eval sketchybar $BATCH

# (chain glyphs after left_sep so they sit in scroll order. sketchybar otherwise
# orders items by add-time, which doesn't match rift.)
if [[ ${#ORDER[@]} -gt 0 ]]; then
  MOVE=""
  PREV="left_sep"
  for item in "${ORDER[@]}"; do
    MOVE="$MOVE --move $item after $PREV"
    PREV="$item"
  done
  sketchybar $MOVE
fi

printf '%s ' "${!FOCUSED_SET[@]}" > "$STATE"
