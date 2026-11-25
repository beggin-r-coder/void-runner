class_name CorridorDirector
extends Node3D
## Streams certified corridor chunks ahead of the ship.
## Pipeline per chunk: difficulty band -> compatible module -> hazard params
## (hazard RNG) -> reachability certification (retry, else safe recovery
## chunk) -> pickups on the certified route (pickup RNG) -> decoration
## (cosmetic RNG). Seed + GENERATOR_VERSION reproduce a run's layout.

signal chunk_planned(plan: ChunkPlan)

const GENERATOR_VERSION := 1
const MAX_ATTEMPTS := 10
const DESPAWN_BEHIND := 40.0

var handling: HandlingConfig
var difficulty: DifficultyProfile
var dresser: WorldDresser
var seeds: SeedService = SeedService.new()
var grid: ReachGrid
var defs: Array[ChunkDefinition] = []
var plans: Array[ChunkPlan] = []
## Spawned (active) chunks vs. data-only chunks prepared ahead.
var active_target: int = 8
var prepared_ahead: int = 2
var rejected_layouts: int = 0
var fallback_count: int = 0
var run_seed: int = 0
## perf instrumentation: planning cost (any thread) and main-thread time in update
var plan_usec_max: int = 0
var plan_usec_total: int = 0
var plan_count: int = 0
var main_usec_max: int = 0
## Plan new chunks on a WorkerThreadPool task (removes main-thread hitches).
var async_planning: bool = true
var _task_id: int = -1
var _task_plan: ChunkPlan

var _recovery_def: ChunkDefinition
var _next_z: float = 0.0
var _next_distance: float = 0.0
var _exit_mask: PackedByteArray
var _route_cell: int = 0
var _chunk_index: int = 0
var _pressure: float = 0.0
var _recovery_queue: int = 0
var _last_theme: int = 0


func setup(p_handling: HandlingConfig, p_difficulty: DifficultyProfile, p_dresser: WorldDresser = null) -> void:
	handling = p_handling
	difficulty = p_difficulty
	dresser = p_dresser
	grid = ReachGrid.new(handling.bounds_half_width, handling.bounds_half_height)
	defs = ModuleLibrary.definitions()
	for d in defs:
		if d.is_recovery:
			_recovery_def = d


func reset(seed_value: int, ship_z: float = 0.0, start_distance: float = 0.0, opening_recovery: int = 2) -> void:
	_drop_pending()
	clear()
	run_seed = seed_value
	seeds.reset(seed_value, GENERATOR_VERSION)
	_next_z = ship_z + 30.0
	_next_distance = start_distance - 30.0
	_exit_mask = grid.full()
	_route_cell = grid.nearest_cell(_exit_mask, Vector2.ZERO)
	_chunk_index = 0
	_pressure = 0.0
	_recovery_queue = opening_recovery
	_last_theme = difficulty.theme_for(maxf(_next_distance, 0.0))
	rejected_layouts = 0
	fallback_count = 0
	fill(1000, false)


func clear() -> void:
	for p in plans:
		if dresser:
			dresser.despawn(p)
	plans.clear()


func speed_at(distance: float) -> float:
	var t := clampf(distance / handling.speed_ramp_distance, 0.0, 1.0)
	return lerpf(handling.base_speed, handling.max_speed, pow(t, 0.85))


## Call once per physics frame. `budget` limits scene activations per frame.
func update_for_ship(ship_z: float, budget: int = 1) -> void:
	var t0 := Time.get_ticks_usec()
	while not plans.is_empty() and plans[0].z_end() > ship_z + DESPAWN_BEHIND:
		var p: ChunkPlan = plans.pop_front()
		if dresser:
			dresser.despawn(p)
	fill(budget, async_planning)
	main_usec_max = maxi(main_usec_max, Time.get_ticks_usec() - t0)


## Keeps active + prepared plans available. With `async`, chunks beyond the
## active window are planned on a worker thread; only an active-window
## shortfall is planned synchronously.
func fill(budget: int, async: bool = false) -> void:
	if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		_finish_pending()
	while plans.size() < active_target + prepared_ahead:
		if async and plans.size() >= active_target:
			if _task_id < 0:
				_task_id = WorkerThreadPool.add_task(_plan_task, false, "void_runner_plan")
			break
		_finish_pending()
		if plans.size() >= active_target + prepared_ahead:
			break
		_append(_plan_next())
	var spawned := 0
	for i in mini(active_target, plans.size()):
		if plans[i].root == null and dresser and spawned < budget:
			dresser.spawn(plans[i], self, seeds.stream("cosmetic"))
			spawned += 1


func _plan_task() -> void:
	_task_plan = _plan_next()


func _finish_pending() -> void:
	if _task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	var plan := _task_plan
	_task_plan = null
	if plan:
		_append(plan)


## Waits for an in-flight plan and discards it (the run is being reset).
func _drop_pending() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	_task_plan = null


## Main thread: give the plan its world position and queue it.
func _append(plan: ChunkPlan) -> void:
	plan.z_start = _next_z
	_next_z -= plan.length
	plans.append(plan)
	chunk_planned.emit(plan)


func _exit_tree() -> void:
	_drop_pending()


func shift_origin(dz: float) -> void:
	for p in plans:
		p.z_start += dz
		if p.root:
			p.root.position.z += dz
	_next_z += dz


func plan_at(z_world: float) -> ChunkPlan:
	for p in plans:
		if z_world <= p.z_start and z_world > p.z_end():
			return p
	return null


## Certified route position at world z (for the autopilot / attract mode).
func safe_target(z_world: float) -> Vector2:
	var p := plan_at(z_world)
	if p == null or p.safe_path.is_empty():
		return Vector2.ZERO
	var lz := z_world - p.z_start
	var path := p.safe_path
	if lz >= path[0].z:
		return Vector2(path[0].x, path[0].y)
	for k in range(1, path.size()):
		if path[k].z <= lz:
			var a := path[k - 1]
			var b := path[k]
			var t := (lz - a.z) / minf(b.z - a.z, -0.0001)
			return Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t))
	var last := path[path.size() - 1]
	return Vector2(last.x, last.y)


func _pick(band: int, rng: RandomNumberGenerator) -> ChunkDefinition:
	var total := 0.0
	for d in defs:
		if not d.is_recovery and d.min_band <= band:
			total += d.weight
	var r := rng.randf() * total
	for d in defs:
		if not d.is_recovery and d.min_band <= band:
			r -= d.weight
			if r <= 0.0:
				return d
	return defs[1]


func _plan_next() -> ChunkPlan:
	var t0 := Time.get_ticks_usec()
	var plan := _plan_next_impl()
	var dt := Time.get_ticks_usec() - t0
	plan_usec_max = maxi(plan_usec_max, dt)
	plan_usec_total += dt
	plan_count += 1
	return plan


func _plan_next_impl() -> ChunkPlan:
	var dist := maxf(_next_distance, 0.0)
	var band := difficulty.band_for(dist)
	var theme := difficulty.theme_for(dist)
	var speed := speed_at(dist + 120.0)
	var route := seeds.stream("route")
	var hazard := seeds.stream("hazard")
	var def: ChunkDefinition
	if _recovery_queue > 0:
		def = _recovery_def
		_recovery_queue -= 1
	elif theme != _last_theme:
		def = _recovery_def  # breathing space at every sector transition
	elif _pressure >= difficulty.pressure_seconds * speed:
		def = _recovery_def
		_pressure = 0.0
	else:
		def = _pick(band, route)
	_last_theme = theme

	var plan := ChunkPlan.new()
	plan.index = _chunk_index
	plan.band = band
	plan.theme = theme
	plan.speed = speed
	var obstacles: Array = []
	var result: Dictionary = {}
	var attempts := 0
	# Certify from where the previous certified route ended, so the route is
	# one continuous controller-feasible line through every chunk.
	var entry := PackedByteArray()
	entry.resize(grid.cell_count())
	entry[_route_cell] = 1
	while attempts < MAX_ATTEMPTS:
		attempts += 1
		obstacles = ModuleLibrary.generate(def, hazard, band, difficulty.density_for(band))
		result = grid.propagate(entry, obstacles, 0.0, -def.length, speed, handling)
		if result["ok"]:
			break
		rejected_layouts += 1
	if not result["ok"]:
		# Insert a known-safe recovery chunk rather than an unfair layout.
		def = _recovery_def
		obstacles = []
		result = grid.propagate(entry, obstacles, 0.0, -def.length, speed, handling)
		plan.fell_back = true
		fallback_count += 1
	plan.definition = def
	plan.length = def.length
	plan.obstacles = obstacles
	plan.attempts = attempts
	plan.exit_mask = result["exit"]
	plan.safe_path = _smooth_route(grid.backtrack(result, Vector2(0.0, 0.0), obstacles), obstacles)
	if not plan.safe_path.is_empty():
		var last := plan.safe_path[plan.safe_path.size() - 1]
		_route_cell = grid.cell_index(Vector2(last.x, last.y))
	plan.start_distance = _next_distance
	_place_pickups(plan, seeds.stream("pickup"))
	_exit_mask = result["exit"]
	if not def.is_recovery:
		_pressure += def.length
	_next_distance += def.length
	_chunk_index += 1
	return plan


## Moving-average smoothing of the quantized route; a smoothed point is kept
## only where it preserves the certified clearance. Endpoints stay fixed so
## routes remain continuous across chunks.
func _smooth_route(path: PackedVector3Array, obstacles: Array) -> PackedVector3Array:
	var n := path.size()
	if n < 5:
		return path
	var inflate := handling.ship_radius + handling.safety_margin + 0.2
	var out := path.duplicate()
	for pass_i in 3:
		var src := out.duplicate()
		for k in range(2, n - 2):
			var avg := (src[k - 2] + src[k - 1] + src[k] + src[k + 1] + src[k + 2]) / 5.0
			avg.z = path[k].z
			for alpha in [1.0, 0.66, 0.33]:
				var cand: Vector3 = src[k].lerp(avg, alpha)
				var ok := true
				for o in obstacles:
					if (o as ObstacleSpec).surface_distance(cand) < inflate:
						ok = false
						break
				if ok:
					out[k] = cand
					break
	return out


## Energy lines follow the certified route so they also teach safe lines.
func _place_pickups(plan: ChunkPlan, rng: RandomNumberGenerator) -> void:
	var chance := 0.9 if plan.definition.is_recovery else 0.5
	if rng.randf() > chance or plan.safe_path.size() < 12:
		return
	var count := rng.randi_range(5, 8)
	var stride := 3
	var start := rng.randi_range(2, maxi(plan.safe_path.size() - count * stride - 1, 2))
	for i in count:
		var k := start + i * stride
		if k >= plan.safe_path.size():
			break
		plan.pickups.append(plan.safe_path[k])
