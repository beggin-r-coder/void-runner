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
| Android SDK / NDK / build-tools | _record on first export machine_ |
| Target API | must be **36+** for Play submissions after 31 Aug 2026 – verify the 4.7.2 template's target before submission; switch to a Gradle build if needed |
| Signing | release keystore kept outside the repository; `export_credentials.cfg` is git-ignored |

## Verification environment used for this build

Linux x86_64, Godot 4.7.2 headless + Xvfb, Mesa lavapipe (llvmpipe) software Vulkan for renders.
Software rendering proves shaders compile and frames render; it says nothing about phone
performance – that requires the device matrix.
