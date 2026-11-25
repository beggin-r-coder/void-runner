# Tuning log

All flight values live in `game/data/handling_default.tres` (HandlingConfig). Record every change.

| Date | Change | Why / evidence |
|---|---|---|
| 2026-11-24 | Baseline: speed 35 → 65 m/s over 5000 m (`pow(t, 0.85)`), envelope ±8 m × ±4.5 m, ship radius 0.85 m | Guide p.4 initial envelope 35–65 m/s |
| 2026-11-24 | `max_lateral_speed` 24 → **28**, `lateral_accel` 110 → **150**, vertical 17/85 → **20/120**, `steer_response` 10 → **14** | Snappier dodge = more achievable near misses; bot study showed 24/110 left routes un-followable at 65 m/s |
| 2026-11-24 | `safety_margin` 0.4 → **0.7** m (hazards inflated by 1.55 m) | 0.4 m left no room for tracking error; bot crashed in 2–80 % of chains depending on band |
| 2026-11-24 | `reach_efficiency` 0.7 → **0.55** (validator assumes 55 % of max lateral speed) | Validator ignored acceleration ramp; 0.55 + margin 0.7 gives 0 bot crashes in 480 chains while keeping band-3 fallbacks ≈ 4 % |
| 2026-11-24 | Certified route made continuous across chunks (each chunk certified from the previous route's end cell) | Independent per-chunk routes jumped at chunk seams – the biggest bot failure source |
| 2026-11-24 | Route backtracking prefers real obstacle clearance and penalises zig-zags; partial smoothing | Remaining failures were 1-cell zig-zags right beside hazards |
| 2026-11-24 | Near-miss threshold **1.7 m** surface clearance, combo max 5, timeout 4 s, 40 pts | Guide p.3 contract; soak bot averages ~35 near misses per 2.2 km |
| 2026-11-24 | Ring hole half-size ≥ 2.9 × 2.4 m, canyon edge growth 0.7/band, debris density 9+3·band | Keep band-3 fallback (recovery chunk) rate near 4 % |
| 2026-11-25 | Slalom walls always ≥ 30 m apart (3 walls per 120 m), reach −0.5…1.0 m past centre | Autotest crashed at 6 km: at ≥ 62 m/s the 22.5 m band-3 slalom caused 100 % of bot crashes (~4 % of chains). After: 0/1200 at 55–65 m/s |
| 2026-11-25 | Hull: no clearcoat, metallic 0.2; ship key light 1.4 → 3.2 | Screenshot review: white NOVA hull rendered dull grey under the Mobile renderer (clearcoat), fine under Compatibility |
| 2026-11-25 | Audio: master hard limiter (−1 dB), boom normalised and −4 dB, engine cut on crash, seamless folded loops, ambient pad on menu/results | Measured: crash clipped at 0 dBFS, boom asset itself clipped (+3.3 dB), engine/wind loops clicked once per second, results screen −64 dB (silent) |
| 2026-11-25 | Barrel roll: 0.5 s, 4.5 m sidestep, ×1.7 lateral speed / ×2.2 accel during the roll, 0.9 s cooldown | Adds a skill dodge; only ever increases capability beyond what the fairness validator assumes, collision sphere unchanged |
| 2026-11-25 | Visual tilt is a damped spring (k 140, damping 0.62) with 0.06 s acceleration anticipation; bank 40 → 52 deg, pitch 16, yaw 9; idle hover 7 cm | More readable, lively motion; purely visual (collision unchanged) |
| 2026-11-25 | Engine plume rebuilt: flow shader on a swept mesh + heat sheath; length / throttle / tail-bend on springs (no per-frame randomness); nozzle ribbons reduced to thin wisps; surges 0.6 launch, 0.7 roll, 0.3+0.06·combo near miss | Old plume was a cone with per-frame random length (rigid/jittery) and its UVs put the bright end at the tail; long uniform nozzle ribbons read as rigid beams |
| 2026-11-25 | Smooth steering (player only; autopilot keeps validated P+FF): adaptive input filter 16–48 /s over 1.5 m, braking curve sqrt(2·0.55·a·d), jerk limit 2400 m/s³ | `--trace-steer`: peak jerk 20,214 → 2,410 m/s³, RMS jerk 5,383 → 862, shaky-thumb vx σ 0.645 → 0.101 m/s, overshoot 0.40 → 0.22 m, 90 % rise 0.217 → 0.267 s. Sweep: brake 0.75 overshot 0.60 m; 0.4 sluggish/jittery |
| 2026-11-25 | Camera: critically damped follow (ω 7.5), 2.2 m look lead into turns, simplex-noise shake, springy FOV; tilt spring 140/0.62 → 120/0.74; hit-stop and crash slow-mo eased instead of snapped | Per-frame random shake and instant time-scale changes read as jerks |

Open questions for the playtest: does the extra ~50 ms of rise time from smoothing feel floaty, or just fluid? (Tune live with --steer_jerk / --brake_factor.) is the roll cooldown (0.9 s) too generous, and are thumb roll buttons reachable without breaking the steering drag? drag gain (26 m per screen height) on small phones; whether the
first-run safe opening (4 recovery chunks) is too long; camera height 2.3 m vs. readability.
