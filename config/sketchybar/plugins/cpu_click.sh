#!/usr/bin/env bash
IS_FRONT=$(osascript -e 'tell application "System Events" to set frontApp to name of first application process whose frontmost is true' 2>/dev/null)
if [[ "$IS_FRONT" == "App Tamer" ]]; then
  osascript -e 'tell application "System Events" to set visible of process "App Tamer" to false'
else
  open -a "App Tamer"
fi
