#!/usr/bin/env bash
# Per-world performance profile on a virtual screen (Xvfb + lavapipe).
# Usage: tools/perf.sh [seconds_per_world] [WxH] [extra dev flags...]
set -euo pipefail
cd "$(dirname "$0")/.."
SECS="${1:-6}"; RES="${2:-1280x720}"; shift $(( $# < 2 ? $# : 2 ))
GODOT="${GODOT:-godot}"
[ -f /opt/lavapipe/lvp_icd.json ] && export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --path . --rendering-method mobile --resolution "$RES" \
  -- --fresh "--perf=$SECS" "$@" 2>&1 | grep "^\[perf\]"
