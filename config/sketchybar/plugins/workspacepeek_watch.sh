#!/usr/bin/env bash
# (catch workspace switches that skip a keybind/click, e.g. focus-follows-mouse, and
# fire aerospace_workspace_change so pills and glyphs refresh.)
AEROSPACE=/opt/homebrew/bin/aerospace
SKETCHYBAR=/opt/homebrew/bin/sketchybar
LAST_WORKSPACE=""

# (timeout, this polls forever so a blocked aerospace call can't hang the loop)
asp() { perl -e 'alarm shift; exec @ARGV' 3 "$AEROSPACE" "$@"; }

while true; do
    CURRENT=$(asp list-workspaces --focused --format "%{workspace}" 2>/dev/null)
    if [[ -n "$CURRENT" && "$CURRENT" != "$LAST_WORKSPACE" ]]; then
        LAST_WORKSPACE="$CURRENT"
        $SKETCHYBAR --trigger aerospace_workspace_change
    fi
    sleep 0.5
done
