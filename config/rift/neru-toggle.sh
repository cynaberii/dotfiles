#!/bin/bash
# (toggle neru on/off. it's resource-heavy with no window, so kill it to free RAM
# when idle and relaunch on demand. -g relaunches without stealing focus.)
if /usr/bin/pgrep -x neru >/dev/null 2>&1; then
  /usr/bin/killall neru
else
  /usr/bin/open -g -a Neru
fi

# (nudge sketchybar to refresh the glyph now instead of waiting for the poll)
/usr/bin/pgrep -x sketchybar >/dev/null 2>&1 && sketchybar --trigger neru_toggle 2>/dev/null
