#!/usr/bin/env bash
# (one glyph per window on the focused workspace. hot path, fires on every switch,
# so query only the focused workspace and track items in a state file instead of
# parsing sketchybar. glyphs follow aerospace's window order.)
source "$HOME/.cache/wal/colors-sketchybar.sh"
AEROSPACE=/opt/homebrew/bin/aerospace
source "$HOME/.config/sketchybar/icon_map.sh"

# (timeout so a blocked aerospace CLI can't pile up hung procs)
asp() { perl -e 'alarm shift; exec @ARGV' 3 "$AEROSPACE" "$@"; }

# (single-instance guard, PID lockfile since macOS has no flock)
LOCK="/tmp/sketchybar-windows.lock"
if [[ -f "$LOCK" ]] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

STATE="/tmp/sketchybar-window-items"

FOCUSED_WS=$(asp list-workspaces --focused --format "%{workspace}")
FOCUSED_WIN=$(asp list-windows --focused --format "%{window-id}" 2>/dev/null)

WINS=$(asp list-windows --workspace "$FOCUSED_WS" --format "%{window-id}|%{app-name}" 2>/dev/null)

declare -A HAVE
if [[ -f "$STATE" ]]; then
  for id in $(<"$STATE"); do HAVE[$id]=1; done
fi

declare -A FOCUSED_SET
BATCH=""

while IFS='|' read -r WIN_ID APP; do
  [[ -z "$WIN_ID" ]] && continue
  [[ "$APP" == "Python" || "$APP" == "python3" ]] && continue
  FOCUSED_SET[$WIN_ID]=1

  __icon_map "$APP"
  ICON=$icon_result

  if [[ "$WIN_ID" == "$FOCUSED_WIN" ]]; then
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
        click_script=\"$AEROSPACE focus --window-id $WIN_ID\" \
        drawing=on"
  fi
done <<< "$WINS"

# (drop items for windows no longer on the focused workspace; re-added cheaply on return)
for id in "${!HAVE[@]}"; do
  [[ -z "${FOCUSED_SET[$id]}" ]] && BATCH="$BATCH --remove window.$id"
done

[[ -n "$BATCH" ]] && eval sketchybar $BATCH

printf '%s ' "${!FOCUSED_SET[@]}" > "$STATE"
