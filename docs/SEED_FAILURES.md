# Seed failure list

Record any seed that produces an unfair, unreachable or bot-failing layout. Include generator version.

| Generator | Seed | Band | Start distance | Symptom | Status |
|---|---|---|---|---|---|
| v1 | 3251602 | 3 | 3060 m | Physics-free bot following the certified route clips a gauntlet ring frame by 0.21 m (reachability itself certified OK) | Open – 1 of 2000 chains; candidate for route smoothing / module tweak |

Reproduce: `d.reset(seed, 0.0, start_distance, 0)` in a `CorridorDirector` with the default
HandlingConfig and DifficultyProfile, then follow with `RouteFollower`.
