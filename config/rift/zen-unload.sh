#!/bin/bash
# (bulk-unload background zen tabs to free RAM, they stay in the strip and reload on
# click. bumps a trigger file's mtime, the matugen-bridge mod polls it (~1s) and
# calls unloadAllTabs(). same trick as the web-theme toggle.)
set -euo pipefail

TRIGGER="$HOME/.cache/quickshell/zen_tab_unload_trigger"
mkdir -p "$(dirname "$TRIGGER")"
: > "$TRIGGER"          # (truncate + touch mtime so the bridge sees the change)

# (WalNotify HUD. kill any still on screen so rapid presses don't stack.)
NOTIFY="$HOME/.local/bin/WalNotify"
/usr/bin/pkill -x WalNotify 2>/dev/null || true
[ -x "$NOTIFY" ] && "$NOTIFY" --raw "˚₊‧ ꒰ঌ zen tabs unloaded ໒꒱ ‧₊˚ ✧" >/dev/null 2>&1 &
disown 2>/dev/null || true
