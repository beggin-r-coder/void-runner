# Seed failure list

Record any seed that produces an unfair, unreachable or bot-failing layout. Include generator version.

| Generator | Seed | Band | Start distance | Symptom | Status |
|---|---|---|---|---|---|
| v1 | 3251602 | 3 | 3060 m | Physics-free bot following the certified route clips a gauntlet ring frame by 0.21 m (reachability itself certified OK) | Open – 1 of 2000 chains; candidate for route smoothing / module tweak |

Reproduce: `d.reset(seed, 0.0, start_distance, 0)` in a `CorridorDirector` with the default
HandlingConfig and DifficultyProfile, then follow with `RouteFollower`.
| v1 | soak run 15 (force_seed 1234 → run seed 1248) | 3+ / top speed | 6,270 m | In-engine physics autopilot clipped a canyon rock spire at 65 m/s (kinematic model survives the same streamed seeds) – 1 crash in 325 km of soak flight | Open – investigate physics-vs-model gap at top speed (sphere sweep vs SDF, speed ramp during warp-free run) |
