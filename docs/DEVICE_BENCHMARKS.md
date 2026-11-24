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

## Automated (non-device) evidence, 2026-11-24

| Check | Result |
|---|---|
| 50 run/retry cycles, physics autopilot (not invulnerable), 4500 m each through all 3 sectors | 50/50 survived, ~100 near misses per run |
| Pool leak check after 50 cycles | leak-free: created == peak concurrent per key (obs_0 69, obs_1 101, obs_2 45, obs_3 12, orbs 56, dressings 8 each). Pools are now prewarmed to those peaks |
| Retry transition (world reset + regenerate 10 chunks) | ~50 ms on desktop CPU (target < 2 s on device) |
