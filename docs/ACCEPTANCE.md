# Acceptance evidence

Attach build hash, device, seed and evidence to every result (guide p.11).
Last full run 2026-11-25, Godot 4.7.2-stable, Linux x86_64 headless / Xvfb + lavapipe (not a phone).

| Guide check | How | Result |
|---|---|---|
| Swept collision: 65 m/s, 30 FPS steps, 0.5 m obstacle, 100/100 | `run_tests.gd` → swept collision | ✅ 100/100 |
| Reachability: 1,000 seeds per speed band, continuous reachable safe volume | `run_tests.gd -- --seeds=1000` | ✅ 16,000 chunks, 0 broken; recovery fallback 0 / 0 / 1.3 / 4.1 % by band |
| Certified route keeps ship radius + margin clearance | same | ✅ all bands |
| Visible-but-unreachable gap is rejected | same | ✅ |
| Bot on the certified route (real accel limits) survives | same (250 seeds/band) and 2000-chain study | ✅ 1000/1000 (bands 0–2), 249/250 band 3; 1999/2000 overall – see SEED_FAILURES.md |
| Near-miss integrity: repeated passes + revive pay once; combo resets | `run_tests.gd` → near-miss, scoring | ✅ |
| Same reward event applied twice credits once | `run_tests.gd` → save | ✅ |
| Current / previous-version / truncated / corrupt saves | `run_tests.gd` → save | ✅ migrate v1, backup recovery, reset with status |
| Acquire/reset/release 1,000× with fixed capacity | `run_tests.gd` → pool | ✅ |
| Duplicate crash callbacks rejected | `run_tests.gd` → session, `flow_smoke.gd` | ✅ |
| Pause on focus loss, held touches cleared, retry < 2 s | `flow_smoke.gd` | ✅ (retry ≈ 50 ms desktop) |
| 50 run/retry cycles without crash or pool growth | `--soak=50 --soak-distance=6500` (physics autopilot, collisions on, 1/60 s steps) | ⚠️ 49/50 reached 6.5 km (325 km flown, ~6,000 near misses); 1 autopilot crash at 65 m/s into a canyon pillar at 6,270 m. Pools leak-free (created = peak concurrent per key) |
| Ad / purchase callback simulations | – | ⛔ not in prototype scope |
| Physical-device scenarios, performance budgets | – | ⏳ needs reference phones (DEVICE_BENCHMARKS.md) |
| 10-person unfamiliar-player gate | – | ⏳ founders to run |
| Automated playthrough (16 stages: UI clicks, drag, pause via buttons + Esc, all bands/sectors to 65 m/s, crash, results ledger, purchase refuse+succeed, settings, retry) | `-- --fresh --autotest` (and `--no-warp`) | ✅ 17/17 (now incl. barrel roll stage); `--no-warp` flew 6.2 km for real, 104 near misses |
| Bot at top speed (65 m/s) | `run_tests.gd` bot survival | ✅ 250/250 (after slalom fix; was ~4 % crash) |
| Procedural audio: finite, unclipped, audible, seamless loops, limiter | `tests/audio_check.gd` | ✅ 10/10 sounds |
| Recorded video audio levels | Movie Maker + `volumedetect` | ✅ max −1.0 dBFS (limiter), mean −20.6 dB, 0 clipped samples |
| Save → reload | `--save=user://reload_check.json --autotest --until=results`, relaunch `--state=menu --shot` | ✅ menu shows BEST 9,912 / CREDITS 277 = file contents |
| Real X11 input flow (xdotool clicks/drag/Esc) | `tools/x11_flow.sh` | ✅ after fixing Esc-resume and banner/hint overlap |
| Renders on Mobile (Vulkan) and Compatibility (OpenGL) | `tools/shot.sh … mobile|compat` | ✅ all screens; 1280×720, 1600×720 (20:9), 854×480 |
