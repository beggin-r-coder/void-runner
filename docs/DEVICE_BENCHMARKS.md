# Device benchmarks

Budgets (guide p.8): Low preset p95 ≤ 33.3 ms over a 20-minute representative run; High preset
p95 ≤ 16.7 ms on mid/high reference devices; no gameplay frame > 100 ms after warm-up; PSS ≤ 450 MB,
growth < 10 % between minutes 5 and 20; cold launch to menu ≤ 5 s on midrange; 50 run/retry
cycles without crash, pool growth or stale input; download ≤ 150 MB.

## Reference devices (to fill in on hardware)

| Device | RAM | GPU | OS | Renderer | Preset | Build hash | p95 ms | Max frame ms | PSS MB | Cold start s | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| older phone | 4 GB | | | | Low | | | | | | |
| midrange | 6 GB | | | | High | | | | | | |
| modern | 8 GB | | | | High | | | | | | |

## Field report: build 0.1.0, 2026-11-26

| Device | RAM | SoC / GPU | OS | Result |
|---|---|---|---|---|
| Xiaomi 26021RN18I | 8 GB | Snapdragon 4 Gen 4 | Android 16 | "Laggy, didn't feel playful", Low preset included → optimisation pass in 0.1.1 |

## Optimisation pass (0.1.1) - measured with `tools/perf.sh` at 2400x1080

Software rendering (lavapipe), so absolute numbers are not phone numbers; frame time scales
with per-pixel shading and draw work, which is what changed.

| Build / preset | avg frame | p95 frame | draw calls | primitives (Shattered Belt) | main-thread chunk planning spike |
|---|---|---|---|---|---|
| 0.1.0 High (native 2400x1080) | 307 ms | 380 ms | ~330 | 1.32 M | 5-15 ms (desktop CPU) |
| 0.1.1 High (FSR from ~760p) | **126 ms** | **149 ms** | **~190** | **0.19 M** | **≤1.6 ms** (planning on a worker thread) |
| 0.1.0 Low | 157 ms | 191 ms | | | |
| 0.1.1 Low (FSR from ~620p) | **82 ms** | **97 ms** | | | |

What changed: FSR 1.0 upscaling from ~760p (UI stays native) + dynamic resolution + 60 fps cap;
ship ~60 → ~20 draws (merged static parts, instanced petals); orbs one instanced draw per chunk;
no shadow pass for scenery; 6 spawned chunks instead of 8; low-poly decoration asteroids;
sky noise in the quarter-resolution pass; rock shader 9 → 6 fetches (2 on scenery), no
vertex fetches on scenery; flame noise from a texture instead of per-pixel hashing; post
effect without per-frame mipmaps; shader warm-up at start (the export shader baker cannot see runtime-created materials, so it is not used).

## Automated (non-device) evidence, 2026-11-24

| Check | Result |
|---|---|
| 50 run/retry cycles, physics autopilot (not invulnerable), 4500 m each through all 3 sectors | 50/50 survived, ~100 near misses per run |
| Pool leak check after 50 cycles | leak-free: created == peak concurrent per key (obs_0 69, obs_1 101, obs_2 45, obs_3 12, orbs 56, dressings 8 each). Pools are now prewarmed to those peaks |
| Retry transition (world reset + regenerate 10 chunks) | ~50 ms on desktop CPU (target < 2 s on device) |
