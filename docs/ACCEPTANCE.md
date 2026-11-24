# Acceptance evidence

Attach build hash, device, seed and evidence to every result (guide p.11).
Run on 2026-11-24, Godot 4.7.2-stable, Linux x86_64 headless (not a phone).

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
| 50 run/retry cycles without crash or pool growth | `--soak=50 --soak-distance=4500` | ✅ 50/50, pools leak-free |
| Ad / purchase callback simulations | – | ⛔ not in prototype scope |
| Physical-device scenarios, performance budgets | – | ⏳ needs reference phones (DEVICE_BENCHMARKS.md) |
| 10-person unfamiliar-player gate | – | ⏳ founders to run |
