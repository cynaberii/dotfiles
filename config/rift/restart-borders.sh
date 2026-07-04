#!/bin/bash
# (relaunch borders. bound in rift on purpose so it spawns as a child and inherits
# rift's accessibility trust. ax_focus needs that to resolve rift's SkyLight focus,
# launch it any other way and the glow tracks the wrong window or vanishes.)
pkill -x borders 2>/dev/null
sleep 0.3
exec /bin/bash "$HOME/.config/borders/bordersrc"
