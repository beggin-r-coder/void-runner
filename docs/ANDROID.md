# Android export

1. Install Godot 4.7.2 **export templates** (Editor → Manage Export Templates).
2. Editor Settings → Export → Android: set Java SDK and Android SDK paths. Record SDK, NDK,
   build-tools and template versions in `BUILD_MANIFEST.md`.
3. Create a debug keystore (or let Godot generate one) – keep release keystores **outside** the repo.
4. Project → Export → **Android** preset (already in `export_presets.cfg`): arm64-v8a, immersive,
   `VIBRATE` permission for haptics. Export path `builds/void_runner_debug.apk` (git-ignored).
5. `adb install -r builds/void_runner_debug.apk`, then run the phase-0 smoke: install, touch drag,
   pause on home button / resume, audio, 50 retries.
6. For store builds: Gradle build + AAB, confirm target API ≥ 36, test the signed AAB through a Play
   testing track (guide p.11).

One-command release build: `tools/build_apk.sh` (see the header for the required environment
variables). Build 0.1.0 was exported and verified this way.

Sideload: copy the APK to the phone and open it (allow "install unknown apps" for your file
manager), or `adb install -r VoidRunner-0.1.0.apk`.
