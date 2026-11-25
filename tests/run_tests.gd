extends SceneTree
## Headless acceptance checks (docs/ACCEPTANCE.md).
## Run: godot --headless --path . --script res://tests/run_tests.gd [-- --seeds=1000]

const HANDLING := preload("res://game/data/handling_default.tres")
const DIFFICULTY := preload("res://game/data/difficulty_default.tres")

var failures: int = 0
var passes: int = 0
var seeds_per_band: int = 200
var only: String = ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds_per_band = int(a.substr(8))
		elif a.begins_with("--only="):
			only = a.substr(7)
	print("== Void Runner acceptance checks ==")
	if _want("scoring"): test_scoring()
	if _want("nearmiss"): test_near_miss_integrity()
	if _want("session"): test_run_session()
	if _want("seed"): test_seed_determinism()
	if _want("reach"): test_reachability()
	if _want("bot"): test_bot_survival()
	if _want("pool"): test_pool_cycling()
	if _want("save"): test_save_store()
	if _want("sweep"): await test_swept_collision()
	print("== %d passed, %d failed ==" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _want(name: String) -> bool:
	return only.is_empty() or name in only.split(",")


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  PASS ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func test_scoring() -> void:
	print("[scoring contract]")
	var s := ScoreService.new(HANDLING)
	s.distance = 123.9
	check(s.score() == 123, "score = floor(distance) with no near misses")
	var pts: Array[int] = []
	for i in 6:
		pts.append(s.register_near_miss())
	check(pts == [40, 80, 120, 160, 200, 200], "near-miss points 40 x combo, combo caps at 5")
	check(s.score() == 123 + 800, "score accumulates near-miss points")
	s.tick(3.9)
	check(s.combo == 5, "combo survives 3.9 s")
	s.tick(0.2)
	check(s.combo == 0, "combo expires after 4 s without a close pass")
	s.register_near_miss()
	s.on_revive()
	check(s.combo == 0, "combo resets on revive")


func test_near_miss_integrity() -> void:
	print("[near-miss integrity]")
	var sensor := NearMissSensor.new()
	sensor.threshold = HANDLING.near_miss_distance
	sensor.ship_radius = HANDLING.ship_radius
	var plan := ChunkPlan.new()
	plan.index = 3
	plan.z_start = 0.0
	plan.length = 100.0
	plan.obstacles = [ObstacleSpec.pillar(Vector3(0, 0, -50), 1.0, 9.0, 0)]
	var paid := 0
	# fly past at 1.0 m clearance (x = 1 + 0.85 + 1.0)
	for pass_i in 3:
		for k in 100:
			var z := -30.0 - k * 0.5
			paid += sensor.update(Vector3(2.85, 0, z), [plan]).size()
		if pass_i == 1:
			sensor.clear_tracking()  # revive
	check(paid == 1, "one obstacle pays exactly once (repeated passes + revive)")
	sensor.reset()
	var far := 0
	for k in 100:
		far += sensor.update(Vector3(6.0, 0, -30.0 - k * 0.5), [plan]).size()
	check(far == 0, "wide pass does not pay")
	sensor.reset()
	var ring := ChunkPlan.new()
	ring.index = 4
	ring.obstacles = [
		ObstacleSpec.box_span(-12.5, -2.0, -9, 9, -50, 1.6, 0),
		ObstacleSpec.box_span(2.0, 12.5, -9, 9, -50, 1.6, 0),
		ObstacleSpec.box_span(-2.0, 2.0, 2.0, 9, -50, 1.6, 0),
		ObstacleSpec.box_span(-2.0, 2.0, -9, -2.0, -50, 1.6, 0),
	]
	var ring_paid := 0
	for k in 100:
		ring_paid += sensor.update(Vector3(0.6, 0.0, -30.0 - k * 0.5), [ring]).size()
	check(ring_paid == 1, "ring frame pieces share one near-miss id")


func test_run_session() -> void:
	print("[run state machine]")
	var rs := RunSession.new()
	check(rs.start_run(false) and rs.state == RunSession.State.COUNTDOWN, "MENU -> COUNTDOWN")
	check(rs.transition(RunSession.State.RUNNING), "COUNTDOWN -> RUNNING")
	check(rs.pause() and rs.state == RunSession.State.PAUSED, "pause")
	check(not rs.transition(RunSession.State.RESULTS), "PAUSED cannot jump to RESULTS")
	check(rs.resume() and rs.state == RunSession.State.RUNNING, "resume restores previous state")
	check(rs.crash(500), "first crash accepted")
	check(not rs.crash(900) and rs.final_score == 500, "duplicate crash callback rejected")
	check(rs.transition(RunSession.State.RESULTS), "CRASHED -> RESULTS")
	var id := rs.run_id
	check(rs.start_run(false) and rs.run_id == id + 1, "retry starts a new run_id")


func _layout_signature(d: CorridorDirector) -> String:
	var parts: PackedStringArray = []
	for p in d.plans:
		parts.append(str(p.definition.id))
		for o in p.obstacles:
			var s := o as ObstacleSpec
			parts.append("%.3f,%.3f,%.3f" % [s.center.x, s.center.y, s.center.z])
	return ",".join(parts)


func test_seed_determinism() -> void:
	print("[seeded reproduction]")
	var d := CorridorDirector.new()
	d.setup(HANDLING, DIFFICULTY)
	d.reset(424242, 0.0, 1700.0)
	var a := _layout_signature(d)
	d.reset(424242, 0.0, 1700.0)
	var b := _layout_signature(d)
	check(a == b, "same seed + generator version reproduces the layout")
	d.reset(424242, 0.0, 1700.0)
	for i in 500:
		d.seeds.stream("cosmetic").randf()
	d.clear()
	d.reset(424242, 0.0, 1700.0)
	check(_layout_signature(d) == a, "cosmetic stream use does not alter gameplay")
	d.reset(777, 0.0, 1700.0)
	check(_layout_signature(d) != a, "different seeds differ")
	d.free()


func test_reachability() -> void:
	print("[reachability: %d seeds per band]" % seeds_per_band)
	var d := CorridorDirector.new()
	d.setup(HANDLING, DIFFICULTY)
	d.active_target = 4
	d.prepared_ahead = 0
	var inflate := HANDLING.ship_radius + HANDLING.safety_margin
	var t0 := Time.get_ticks_msec()
	for band in DIFFICULTY.band_distances.size():
		var start := DIFFICULTY.band_distances[band] + 60.0
		var broken := 0
		var bad_path := 0
		var chunks := 0
		var fallbacks := 0
		for s in seeds_per_band:
			d.reset(1000 + s * 7919 + band, 0.0, start, 0)
			for p in d.plans:
				chunks += 1
				if p.fell_back:
					fallbacks += 1
				if p.safe_path.size() == 0 or p.exit_mask.count(1) == 0:
					broken += 1
				for q in p.safe_path:
					for o in p.obstacles:
						if (o as ObstacleSpec).surface_distance(q) < inflate - 0.001:
							bad_path += 1
		print("    band %d: %d chunks, %d fallbacks (%.1f%%)" % [band, chunks, fallbacks, 100.0 * fallbacks / maxf(chunks, 1)])
		check(broken == 0, "band %d: every chunk chain has a continuous reachable volume" % band)
		check(bad_path == 0, "band %d: certified route keeps ship-radius + margin clearance" % band)
	print("    (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# A layout with no gap at all must be rejected.
	var grid := ReachGrid.new(HANDLING.bounds_half_width, HANDLING.bounds_half_height)
	var wall := [ObstacleSpec.box_span(-12.5, 12.5, -9, 9, -40, 3, 0)]
	check(not grid.propagate(grid.full(), wall, 0, -100, 50, HANDLING)["ok"], "sealed wall is rejected")
	# A visible but unreachable gap must be rejected: gap far left right after a gap far right.
	var zig := [
		ObstacleSpec.box_span(-12.5, 6.0, -9, 9, -20, 2, 0),
		ObstacleSpec.box_span(-6.0, 12.5, -9, 9, -24, 2, 1),
	]
	check(not grid.propagate(grid.full(), zig, 0, -100, 65, HANDLING)["ok"], "visible-but-unreachable gap is rejected")
	d.free()


## Kinematic bot with the real acceleration limits follows the certified
## route through generated chains; it must never touch a hazard.
func test_bot_survival() -> void:
	var n := maxi(seeds_per_band / 4, 25)
	print("[bot survival: %d seeds per band]" % n)
	var d := CorridorDirector.new()
	d.setup(HANDLING, DIFFICULTY)
	d.active_target = 6
	d.prepared_ahead = 0
	var cfg := HANDLING
	# the four difficulty bands plus a top-speed (65 m/s) case
	var starts: Array[float] = []
	for bd in DIFFICULTY.band_distances:
		starts.append(bd + 60.0)
	starts.append(HANDLING.speed_ramp_distance + 600.0)
	for band in starts.size():
		var crashes := 0
		var min_clear := INF
		var failed_seeds: Array[int] = []
		for s in n:
			var start := starts[band]
			var seed_value := 5000 + s * 104729 + band
			d.reset(seed_value, 0.0, start, 0)
			var follower := RouteFollower.new(d)
			var p0 := d.plans[0]
			var pos := Vector3(p0.safe_path[0].x, p0.safe_path[0].y, p0.z_start)
			var vel := Vector2.ZERO
			var dist := start
			var end_z := d.plans[d.plans.size() - 1].z_end() + 5.0
			var dt := 1.0 / 60.0
			while pos.z > end_z:
				var speed := d.speed_at(dist)
				var res := follower.sample(pos.z, speed)
				var desired: Vector2 = (res[0] - Vector2(pos.x, pos.y)) * follower.gain + res[1]
				desired.x = clampf(desired.x, -cfg.max_lateral_speed, cfg.max_lateral_speed)
				desired.y = clampf(desired.y, -cfg.max_vertical_speed, cfg.max_vertical_speed)
				vel.x = move_toward(vel.x, desired.x, cfg.lateral_accel * dt)
				vel.y = move_toward(vel.y, desired.y, cfg.vertical_accel * dt)
				pos += Vector3(vel.x, vel.y, -speed) * dt
				pos.x = clampf(pos.x, -cfg.bounds_half_width, cfg.bounds_half_width)
				pos.y = clampf(pos.y, -cfg.bounds_half_height, cfg.bounds_half_height)
				dist += speed * dt
				var p := d.plan_at(pos.z)
				if p == null:
					continue
				var local := pos - Vector3(0, 0, p.z_start)
				var hit := false
				for o in p.obstacles:
					var c := (o as ObstacleSpec).surface_distance(local) - cfg.ship_radius
					min_clear = minf(min_clear, c)
					if c < 0.0:
						hit = true
				if hit:
					crashes += 1
					failed_seeds.append(seed_value)
					break
		var rate := 1.0 - float(crashes) / n
		if not failed_seeds.is_empty():
			print("    band %d failing seeds (generator v%d): %s" % [band, CorridorDirector.GENERATOR_VERSION, failed_seeds])
		var label := ("band %d" % band) if band < DIFFICULTY.band_distances.size() else "top speed 65 m/s"
		check(rate >= 0.995, "%s: bot on the certified route survives %d/%d chains (>= 99.5%%)" % [label, n - crashes, n])
	d.free()


func test_pool_cycling() -> void:
	print("[pool cycling]")
	var parent := Node3D.new()
	var pool := NodePool.new(parent)
	pool.register(&"obs", func() -> Node: return Node3D.new(), 8)
	var held: Array = []
	for i in 1000:
		held.append(pool.acquire(&"obs"))
		if held.size() >= 8:
			for n in held:
				pool.release(n)
			held.clear()
	for n in held:
		pool.release(n)
	check(pool.created_count == 8, "1000 acquire/release cycles stay within fixed capacity (created %d)" % pool.created_count)
	check(pool.active_count == 0, "no leaked active nodes")
	var n2 := pool.acquire(&"obs")
	pool.release(n2)
	pool.release(n2)
	check(pool.free_count(&"obs") == 8, "double release is ignored")
	parent.free()


func test_save_store() -> void:
	print("[save migration / recovery / ledger]")
	var dir := "user://test_saves"
	DirAccess.make_dir_recursive_absolute(dir)
	var store := SaveStore.new()
	store.path = dir + "/save.json"
	for f in [store.path, store.path + ".bak", store.path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	store.load_save()
	check(store.last_load_status == "fresh", "fresh install")
	var v1 := {"schema_version": 1, "coins": 77, "best_score": 1200, "reduced_motion": true}
	var m := SaveStore.migrate(v1)
	check(m["credits"] == 77 and m["schema_version"] == SaveStore.SCHEMA_VERSION and m["settings"]["reduced_motion"] == true, "v1 save migrates (coins -> credits, settings)")
	store.data = SaveStore.migrate(v1)
	check(store.commit(), "atomic commit")
	store.data["credits"] = 99
	store.commit()  # primary=99, backup=77
	var f := FileAccess.open(store.path, FileAccess.WRITE)
	f.store_string("{\"schema_version\": 2, \"credits\": 9")  # truncated
	f.close()
	store.load_save()
	check(store.last_load_status == "recovered_backup" and store.data["credits"] == 77, "truncated primary recovers last-good backup")
	var f2 := FileAccess.open(store.path, FileAccess.WRITE)
	f2.store_string("garbage")
	f2.close()
	DirAccess.remove_absolute(store.path + ".bak")
	store.load_save()
	check(store.last_load_status == "reset_corrupt" and store.data["credits"] == 0, "corrupt save without backup resets with status")
	var before := int(store.data["credits"])
	var first := store.grant_reward("run:1:1", 25)
	var second := store.grant_reward("run:1:1", 25)
	check(first and not second and store.data["credits"] == before + 25, "same reward event applied twice credits once")
	for f2n in [store.path, store.path + ".bak", store.path + ".tmp"]:
		if FileAccess.file_exists(f2n):
			DirAccess.remove_absolute(f2n)
	DirAccess.remove_absolute(dir)
	store.free()


func test_swept_collision() -> void:
	print("[swept collision]")
	var harness := SweepHarness.new()
	harness.cfg = HANDLING
	root.add_child(harness)
	await harness.done
	check(harness.hits == harness.trials, "65 m/s at 30 FPS steps hits a 0.5 m obstacle in %d/%d passes" % [harness.hits, harness.trials])
	harness.queue_free()


class SweepHarness:
	extends Node3D
	signal done
	var cfg: HandlingConfig
	var trials: int = 100
	var hits: int = 0
	var _trial: int = -1
	var _ship: FlightController
	var _wall: StaticBody3D
	var _hit: bool = false
	var _steps: int = 0

	func _ready() -> void:
		_ship = FlightController.new()
		add_child(_ship)
		_ship.setup(cfg, null)
		_ship.steering_enabled = false
		_ship.crashed.connect(func(_c: Object) -> void: _hit = true)
		_wall = StaticBody3D.new()
		_wall.collision_layer = 2
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 3.0, 0.5)
		cs.shape = box
		_wall.add_child(cs)
		add_child(_wall)
		_next()

	func _next() -> void:
		_trial += 1
		if _trial >= trials:
			done.emit()
			set_physics_process(false)
			return
		_hit = false
		_steps = 0
		# vary phase so the obstacle lands at every offset between frames
		var phase := float(_trial) / trials * (65.0 / 30.0)
		_wall.position = Vector3(0, 0, -20.0 - phase)
		_ship.reset_to(Vector3(0, 0, 0))
		_ship.target = Vector2.ZERO
		_ship.forward_speed = 65.0

	func _physics_process(_delta: float) -> void:
		if _trial < 0 or _trial >= trials:
			return
		_ship.step(1.0 / 30.0)
		_steps += 1
		if _hit or _steps > 30:
			if _hit:
				hits += 1
			_next()
