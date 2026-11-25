#!/usr/bin/env bash
# End-to-end flow driven from OUTSIDE the engine with real X11 input (xdotool) and
# screen grabs (ImageMagick `import -window root`): no in-engine test flags change
# the flow. menu -> tap to launch -> tutorial -> drag steer -> Esc pause -> resume.
# Needs: Xvfb, xdotool, imagemagick. Usage: tools/x11_flow.sh OUT_DIR
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-/tmp/x11_flow}"; mkdir -p "$OUT"
GODOT="${GODOT:-godot}"
[ -f /opt/lavapipe/lvp_icd.json ] && export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
export DISPLAY=:97
Xvfb :97 -screen 0 1280x720x24 >/dev/null 2>&1 & XPID=$!
sleep 1
SAVE=user://x11_flow_save.json
UD="$HOME/.local/share/godot/app_userdata/Void Runner"
rm -f "$UD"/x11_flow_save.json*
"$GODOT" --path . --resolution 1280x720 --position 0,0 -- "--save=$SAVE" >"$OUT/godot.log" 2>&1 & GPID=$!
cleanup() { kill $GPID 2>/dev/null || true; kill $XPID 2>/dev/null || true; rm -f "$UD"/x11_flow_save.json*; }
trap cleanup EXIT
grab() { import -window root "$OUT/$1.png"; echo "grabbed $1"; }
sleep 12;  grab 1_menu
xdotool mousemove 640 300 click 1;          sleep 6; grab 2_after_tap
xdotool mousemove 640 400 mousedown 1;      sleep 1
xdotool mousemove 760 400;                  sleep 4; grab 3_dragging_right
xdotool mouseup 1;                          sleep 1
xdotool key Escape;                         sleep 4; grab 4_paused
xdotool key Escape;                         sleep 4; grab 5_resumed
