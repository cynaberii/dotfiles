#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"

# (keyboard input source, EN/ES/VI. one cheap `defaults` read of the cfprefsd
# domain. an active input method like Vietnamese Telex wins over the base layout.)
RAW="$(defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null)"

case "$RAW" in
  *Vietnamese*)      LABEL="VI" ;;
  *Spanish*)         LABEL="ES" ;;
  *U.S.*|*ABC*|*US*) LABEL="EN" ;;
  *)                 LABEL="--" ;;
esac

sketchybar --set "$NAME" icon="󰌌" icon.color=$WHITE label="$LABEL" label.color=$WHITE
