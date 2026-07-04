#!/usr/bin/env bash
# (push pywal colours to every open wezterm pane via OSC sequences. wezterm ignores
# pywal's default linux-console ]P sequences.)

JQ=/opt/homebrew/bin/jq
WAL_JSON="$HOME/.cache/wal/colors.json"
WEZTERM=/opt/homebrew/bin/wezterm

[[ -f "$WAL_JSON" ]] || exit 0

build_sequences() {
  local bg fg cursor
  bg=$($JQ -r '.special.background' "$WAL_JSON")
  fg=$($JQ -r '.special.foreground' "$WAL_JSON")
  cursor=$($JQ -r '.special.cursor' "$WAL_JSON")

  local seq=""
  # (16 ansi colours, OSC 4)
  for i in $(seq 0 15); do
    local c
    c=$($JQ -r ".colors.color$i" "$WAL_JSON")
    seq+=$'\033]4;'"$i;$c"$'\033\\'
  done
  # (fg OSC 10, bg OSC 11, cursor OSC 12)
  seq+=$'\033]10;'"$fg"$'\033\\'
  seq+=$'\033]11;'"$bg"$'\033\\'
  seq+=$'\033]12;'"$cursor"$'\033\\'
  printf '%s' "$seq"
}

SEQUENCES=$(build_sequences)

$WEZTERM cli list --format json 2>/dev/null \
  | $JQ -r '.[].tty_name' \
  | sort -u \
  | while read -r tty; do
      [[ -n "$tty" && -w "$tty" ]] && printf '%s' "$SEQUENCES" > "$tty" 2>/dev/null
    done
