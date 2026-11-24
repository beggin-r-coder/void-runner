#!/usr/bin/env bash
# Renders the automated screenshot tour (menu, all three sectors, crash,
# results) to ./captures using a real renderer. On headless Linux it uses
# Xvfb + the lavapipe software Vulkan driver when available.
# Usage: tools/capture.sh [out_dir] [WxH]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-$PWD/captures}"
RES="${2:-1280x720}"
GODOT="${GODOT:-godot}"
mkdir -p "$OUT"
if [ -f /opt/lavapipe/lvp_icd.json ]; then
  export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
fi
RUN=("$GODOT" --path . --resolution "$RES" --fixed-fps 30 -- "--capture=$OUT")
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
  xvfb-run -a -s "-screen 0 ${RES}x24" "${RUN[@]}"
else
  "${RUN[@]}"
fi
echo "Screenshots written to $OUT"
