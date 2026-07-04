#!/usr/bin/env bash
# (aerospace runs this before a workspace switch to snapshot the workspace you're leaving)

CACHE_DIR="$HOME/.cache/aerospace-switcher"
AEROSPACE="/opt/homebrew/bin/aerospace"

mkdir -p "$CACHE_DIR"

CURRENT=$("$AEROSPACE" list-workspaces --focused 2>/dev/null)
if [[ -z "$CURRENT" ]]; then
    exit 0
fi

# (temp file then atomic mv so the switcher never reads a half-written png)
TMPFILE=$(mktemp "$CACHE_DIR/ws-tmp-XXXXXX.png")
screencapture -x -m "$TMPFILE"
mv "$TMPFILE" "$CACHE_DIR/ws-${CURRENT}.png"
