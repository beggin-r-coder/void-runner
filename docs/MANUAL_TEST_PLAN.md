# What the headless setup cannot verify — test these by hand on a phone

The automated harness (README "Verify it") proves logic, flow, fairness, save integrity and that
every screen renders. It runs on software rendering with no speakers and no fingers, so:

| Area | Why automation can't tell | What to do on a device |
|---|---|---|
| **Touch feel** | Synthetic drags have perfect precision and zero latency | Is 26 m per screen-height drag gain right on a 6" phone? Does the ship feel like it follows the thumb? Try left- and right-handed, thumb near the screen edge (edge re-anchoring) |
| **Reaction window at 65 m/s** | The bot reacts instantly | Can a new player read and dodge hazards in Silent Spires at top speed? Watch the 10-person gate (≥8 start unaided, ≥7 know why they died, ≥6 replay ×3) |
| **Performance** | lavapipe/llvmpipe is a CPU rasteriser, nothing like a phone GPU | Fill `DEVICE_BENCHMARKS.md`: p95 frame time Low/High, worst frame, PSS, thermal after 20 min, on 4/6/8 GB phones. Compare Mobile vs Compatibility renderer on the 4 GB phone |
| **How it sounds** | Audio is measured (levels, clipping, loop seams), not heard | Engine drone pitch ramp pleasant or grating? Whoosh audible over engine at top speed? Crash boom satisfying? Ambient pad on menu/results ok? Check with phone speaker *and* headphones |
| **Haptics** | Vibration can't be observed | Near-miss tick (18 ms) and crash (140 ms) noticeable but not annoying; off when disabled |
| **Lifecycle** | Focus-loss is simulated | Home button, incoming call, screen lock, notification shade mid-run → paused, no stuck steering on resume. Android back button → pause/resume, never quits mid-run |
| **Readability outdoors / small screens** | Screenshots are viewed on a monitor | HUD and popups legible in sunlight and on the smallest supported phone; 48 dp touch targets comfortable |
| **Motion comfort** | — | Speed streaks, FOV kick, chromatic edge blur: anyone queasy? Does Reduced motion fix it? |
