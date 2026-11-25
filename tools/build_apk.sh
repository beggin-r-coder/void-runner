#!/usr/bin/env bash
# Builds a signed release APK of Void Runner (no Gradle needed).
# Requires: Godot 4.7.2 + export templates installed, Android SDK with
# build-tools (apksigner) + platform-tools, a JDK, and a release keystore.
#
#   GODOT=/path/to/godot ANDROID_SDK=/path/to/sdk \
#   KEYSTORE=/path/release.keystore KEY_ALIAS=voidrunner KEY_PASS=... \
#   tools/build_apk.sh [out.apk]
#
# Signing secrets come from the environment and are never written to the repo.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-builds/VoidRunner-$(grep -oP 'config/version="\K[^"]+' project.godot).apk}"
GODOT="${GODOT:-godot}"
: "${ANDROID_SDK:?set ANDROID_SDK}" "${KEYSTORE:?set KEYSTORE}" "${KEY_ALIAS:?set KEY_ALIAS}" "${KEY_PASS:?set KEY_PASS}"
JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
VER=$("$GODOT" --version | grep -oE '^[0-9]+\.[0-9]+')
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-$VER.tres"
mkdir -p "$(dirname "$CFG")" "$(dirname "$OUT")"
if ! grep -q android_sdk_path "$CFG" 2>/dev/null; then
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' "$ANDROID_SDK" "$JAVA_HOME" > "$CFG"
fi
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEY_ALIAS" \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEY_PASS" \
  "$GODOT" --headless --path . --export-release "Android" "$OUT"
BT=$(ls -d "$ANDROID_SDK"/build-tools/* | sort -V | tail -1)
"$BT/apksigner" verify "$OUT" && echo "Built and verified: $OUT ($(du -h "$OUT" | cut -f1))"
