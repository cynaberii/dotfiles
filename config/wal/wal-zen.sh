#!/usr/bin/env bash
# (feed the zen matugen-bridge from pywal colours, no matugen needed. writes
# matugen-vars.json, the bridge tints every site toward it and hot-reloads on mtime.)

JQ=/opt/homebrew/bin/jq
WAL_JSON="$HOME/.cache/wal/colors.json"
ZEN_CHROME="$HOME/Library/Application Support/zen/Profiles/kd6r9rhz.Default User/chrome"

[[ -f "$WAL_JSON" && -d "$ZEN_CHROME" ]] || exit 0

BG=$($JQ -r '.special.background' "$WAL_JSON")
C0=$($JQ -r '.colors.color0'  "$WAL_JSON")
C2=$($JQ -r '.colors.color2'  "$WAL_JSON")
C3=$($JQ -r '.colors.color3'  "$WAL_JSON")
C7=$($JQ -r '.colors.color7'  "$WAL_JSON")
C8=$($JQ -r '.colors.color8'  "$WAL_JSON")
C10=$($JQ -r '.colors.color10' "$WAL_JSON")
C15=$($JQ -r '.colors.color15' "$WAL_JSON")

$JQ -n \
  --arg bg "$BG" --arg bgd "$C0" --arg bgl "$C8" \
  --arg fg "$C15" --arg fgl "$C7" \
  --arg accent "$C10" --arg sec "$C2" --arg ter "$C3" \
  '{
     "bg": $bg, "bg-dark": $bgd, "bg-light": $bgl,
     "fg": $fg, "fg-light": $fgl,
     "accent": $accent, "secondary": $sec, "tertiary": $ter
   }' > "$ZEN_CHROME/matugen-vars.json"
