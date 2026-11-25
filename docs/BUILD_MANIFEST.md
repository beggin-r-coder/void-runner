# Build manifest

| Item | Value |
|---|---|
| Engine | Godot **4.7.2-stable** (official, `ed1daf0bf`) – pinned; do not upgrade during release hardening without re-running all gates |
| Language | Typed GDScript only |
| Renderer | Mobile (`rendering_method = mobile`, Vulkan). Compatibility renderer still to be compared on a low-end device (guide p.8) |
| Physics | Godot default 3D physics, 60 ticks/s, physics interpolation on |
| Plugins | none |
| Third-party assets | none (see ASSET_REGISTER.md) |
| Android package | `com.dashpanda.voidrunner` |
| Android ABI | arm64-v8a |
| Android SDK | cmdline-tools 16111833, build-tools 36.1.0, platform-tools 37.0.3 (no NDK / Gradle needed for the standard export) |
| JDK | OpenJDK 21 |
| Export templates | Godot 4.7.2.stable official (android_release.apk) |
| Min / target API | **24 / 36** (verified with aapt2 on build 0.1.0) - meets the Android 16 / API 36 Play requirement |
| Renderer requirement | Vulkan (Mobile renderer) - APK declares android.hardware.vulkan.level |
| Signing | release keystore kept outside the repository; `export_credentials.cfg` is git-ignored |

## Verification environment used for this build

Linux x86_64, Godot 4.7.2 headless + Xvfb, Mesa lavapipe (llvmpipe) software Vulkan for renders.
Software rendering proves shaders compile and frames render; it says nothing about phone
performance – that requires the device matrix.

## Builds

| Version | Date | Size | Signed with | Verified |
|---|---|---|---|---|
| 0.1.0 (code 1) | 2026-11-26 | 26.9 MB | session-generated test release key (CN=DashPanda Studios) - **not** the store key | apksigner v2+v3 OK; minSdk 24, targetSdk 36, arm64-v8a |
