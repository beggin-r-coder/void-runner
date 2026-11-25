#!/usr/bin/env bash
# Screenshot tour (menu, all three sectors, crash, results) via the --shots dev flag.
# Usage: tools/capture.sh [out_dir] [WxH] [mobile|compat]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-$PWD/captures}"; RES="${2:-1280x720}"; R="${3:-mobile}"
GODOT="${GODOT:-godot}"
mkdir -p "$OUT"
if [ "$R" = compat ]; then
  RFLAGS=(--rendering-method gl_compatibility --rendering-driver opengl3)
else
  RFLAGS=(--rendering-method mobile --rendering-driver vulkan)
  [ -f /opt/lavapipe/lvp_icd.json ] && export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
fi
xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --path . "${RFLAGS[@]}" --resolution "$RES" \
  --fixed-fps 30 -- --fresh "--shots=$OUT"
echo "Screenshots written to $OUT"
