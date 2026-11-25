#!/usr/bin/env bash
# One screenshot of a game state on a virtual screen (Xvfb + software rendering).
# Usage: tools/shot.sh OUT.png [WxH] [mobile|compat] [extra dev flags...]
#   e.g. tools/shot.sh /tmp/hud.png 1280x720 mobile --state=hud --distance=2100
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$1"; RES="${2:-1280x720}"; R="${3:-mobile}"; shift $(( $# < 3 ? $# : 3 ))
GODOT="${GODOT:-godot}"
if [ "$R" = compat ]; then
  RFLAGS=(--rendering-method gl_compatibility --rendering-driver opengl3)
else
  RFLAGS=(--rendering-method mobile --rendering-driver vulkan)
  [ -f /opt/lavapipe/lvp_icd.json ] && export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
fi
xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --path . "${RFLAGS[@]}" --resolution "$RES" \
  -- --fresh "--shot=$OUT" "$@"
