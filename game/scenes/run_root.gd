extends Node3D
## AppRoot + RunRoot for Void Runner.
## Owns the run state machine, controller, director, camera, scoring, FX and
## local pools. Platform/session services live in DashCore autoloads (Save,
## Sfx). Flow: MENU -> TUTORIAL | COUNTDOWN -> RUNNING -> CRASHED -> RESULTS
## -> MENU / RETRY. PAUSED remembers the previous state.

const HANDLING: HandlingConfig = preload("res://game/data/handling_default.tres")
const DIFFICULTY: DifficultyProfile = preload("res://game/data/difficulty_default.tres")
const THEMES: Array[ThemeProfile] = [
	preload("res://game/data/themes/crimson_reach.tres"),
	preload("res://game/data/themes/shattered_belt.tres"),
	preload("res://game/data/themes/silent_spires.tres"),
]
const SKY_SHADER := preload("res://game/art/shaders/sky.gdshader")
const POST_SHADER := preload("res://game/art/shaders/post.gdshader")
const ORIGIN_SHIFT_AT := 2000.0
const SKY_PARAMS := ["sky_top", "sky_horizon", "sky_bottom", "horizon_glow", "star_strength", "nebula_strength", "nebula_a", "nebula_b", "planet_dir", "planet_radius", "planet_color", "planet_atmo", "planet_strength", "ring_strength", "ring_color", "mega_strength", "mega_color", "sun_color"]

signal run_started(run_id: int)
signal hazard_passed(run_id: int, uid: int, points: int)
signal run_ended(run_id: int, score: int, reason: String)
signal reward_earned(run_id: int, credits: int)

var cfg: HandlingConfig
var session: RunSession = RunSession.new()
var score: ScoreService
var sensor: NearMissSensor = NearMissSensor.new()
var input: InputRouter
var mats: GameMaterials
var world: Node3D
var dresser: WorldDresser
var director: CorridorDirector
var ship: FlightController
var ship_parts: Dictionary
var cam: ChaseCamera
var fx: SpeedFX
var burst: BurstFX
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var ui: GameUI
var post_rect: ColorRect
var post_mat: ShaderMaterial

var reduced_motion: bool = false
var haptics: bool = true
var high_quality: bool = true
var current_theme: int = -1
var _theme_from: ThemeProfile
var _theme_to: ThemeProfile
var _theme_t: float = 1.0
var _countdown_t: float = 0.0
var _countdown_step: int = 0
var _crash_real_t: float = 0.0
var _crash_reason: String = ""
var _hitstop_until: int = 0
var _run_seed: int = 0
var _tutorial_t: float = 0.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE

# Hooks for the dev harness (game/dev/dev_harness.gd). Defaults = normal play.
var time_base: float = 1.0           ## global time scale (autotest fast-forward)
var autopilot_runs: bool = false     ## runs are flown by the RouteFollower
var invulnerable_runs: bool = false  ## runs ignore collisions (screenshot tours)
var force_seed: int = -1             ## >= 0: deterministic run seeds
var allow_tutorial: bool = true
var pause_on_focus_loss: bool = true
var crash_delay: float = 1.1         ## real seconds of crash slow-mo before results
var distance_cap: float = INF        ## end the run (as survived) at this distance
var survived_cap: bool = false
var dev: Node


func _ready() -> void:
	cfg = HANDLING.duplicate() as HandlingConfig
	score = ScoreService.new(cfg)
	sensor.threshold = cfg.near_miss_distance
	sensor.ship_radius = cfg.ship_radius
	input = InputRouter.new()
	input.name = "InputRouter"
	add_child(input)
	mats = GameMaterials.new(THEMES)
	_build_environment()

	world = Node3D.new()
	world.name = "World"
	add_child(world)
	dresser = WorldDresser.new()
	dresser.name = "Dresser"
	world.add_child(dresser)
	dresser.setup(THEMES, mats)
	director = CorridorDirector.new()
	director.name = "CorridorDirector"
	world.add_child(director)
	director.setup(cfg, DIFFICULTY, dresser)
	_follower = RouteFollower.new(director)

	ship = FlightController.new()
	ship.name = "Ship"
	world.add_child(ship)
	ship.setup(cfg, input)
	ship.crashed.connect(_on_crash)
	ship.rolled.connect(_on_rolled)
	cam = ChaseCamera.new()
	cam.name = "ChaseCamera"
	world.add_child(cam)
	cam.current = true
	fx = SpeedFX.new()
	fx.name = "SpeedFX"
	world.add_child(fx)
	fx.setup(cam, mats)
	_build_ship(str(Save.data["livery"]))
	burst = BurstFX.new()
	world.add_child(burst)
	burst.setup(mats)
	cam.setup(ship, cfg)

	_build_ui()
	_apply_settings()
	session.state_changed.connect(_on_state_changed)
	dev = preload("res://game/dev/dev_harness.gd").new()
	dev.name = "DevHarness"
	add_child(dev)
	dev.setup(self)  # parses command-line flags; may adjust hooks above
	_apply_settings()
	_enter_menu()


# --- construction ---------------------------------------------------------------

func _build_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.light_angular_distance = 0.5
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_ship(livery: String) -> void:
	ship_parts = ShipBuilder.build(livery, mats)
	ship.set_visual(ship_parts["root"])
	fx.attach_ship(ship_parts, mats, world)


func _build_ui() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 0
	add_child(post_layer)
	post_rect = ColorRect.new()
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST_SHADER
	post_rect.material = post_mat
	post_layer.add_child(post_rect)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)
	ui = GameUI.new()
	ui_layer.add_child(ui)
	ui.launch_pressed.connect(_start_run)
	ui.retry_pressed.connect(_start_run)
	ui.menu_pressed.connect(_go_menu)
	ui.pause_pressed.connect(_pause)
	ui.resume_pressed.connect(_resume)
	ui.setting_changed.connect(_on_setting_changed)
	ui.livery_selected.connect(_on_livery_selected)
	ui.roll_pressed.connect(_try_roll)
	ui.hangar_toggled.connect(func(open: bool) -> void: cam.framing_target = 1.0 if open else 0.0)


# --- settings ---------------------------------------------------------------------

func _apply_settings() -> void:
	var s: Dictionary = Save.data["settings"]
	reduced_motion = bool(s["reduced_motion"])
	haptics = bool(s["haptics"])
	high_quality = str(s["quality"]) == "high"
	cam.reduced_motion = reduced_motion
	ship.invert_y = bool(s["invert_y"])
	Sfx.volume = float(s["sfx_volume"])
	post_rect.visible = high_quality
	sun.shadow_enabled = high_quality
	fx.quality_high = high_quality
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 1.0 if high_quality else 0.75
	env.glow_bloom = 0.05 if high_quality else 0.02


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "high_quality":
		Save.set_setting("quality", "high" if value else "low")
	else:
		Save.set_setting(key, value)
	_apply_settings()


func _on_livery_selected(id: String) -> void:
	if id.begins_with("preview:"):
		id = id.substr(8)
	_build_ship(id)
	if session.state == RunSession.State.MENU:
		ship.visual.visible = true


# --- themes -----------------------------------------------------------------------

func _set_theme_immediate(index: int) -> void:
	current_theme = index
	_theme_from = THEMES[index]
	_theme_to = THEMES[index]
	_theme_t = 1.0
	_apply_theme(THEMES[index])


func _begin_theme(index: int) -> void:
	if index == current_theme:
		return
	var snapshot := ThemeProfile.blend(_theme_from, _theme_to, _ease_theme(_theme_t))
	current_theme = index
	_theme_from = snapshot
	_theme_to = THEMES[index]
	_theme_t = 0.0
	ui.banner("SECTOR %d  -  %s" % [index + 1, THEMES[index].display_name])


func _ease_theme(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _apply_theme(p: ThemeProfile) -> void:
	for n in SKY_PARAMS:
		sky_mat.set_shader_parameter(n, p.get(n))
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	sun.basis = Basis.looking_at(p.sun_dir.normalized(), Vector3.UP)
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.fog_height = p.fog_height
	env.fog_height_density = p.fog_height_density
	env.fog_sun_scatter = p.fog_sun_scatter
	env.glow_intensity = p.glow_intensity
	env.tonemap_exposure = p.exposure
	fx.set_theme_color(p.speedline_color)


func _update_theme(delta: float) -> void:
	var plan := director.plan_at(ship.position.z)
	if plan and plan.theme != current_theme:
		_begin_theme(plan.theme)
	if _theme_t < 1.0:
		_theme_t = minf(_theme_t + delta / 2.5, 1.0)
		_apply_theme(ThemeProfile.blend(_theme_from, _theme_to, _ease_theme(_theme_t)))


# --- flow ---------------------------------------------------------------------------

func _reset_world(seed_value: int, start_distance: float = 0.0, opening: int = 2) -> void:
	_run_seed = seed_value
	Engine.time_scale = time_base
	ship.reset_to(Vector3.ZERO)
	ship.distance_travelled = start_distance
	ship.forward_speed = cfg.attract_speed
	director.reset(seed_value, 0.0, start_distance, opening)
	score.reset()
	score.distance = start_distance
	sensor.reset()
	fx.clear_trails()
	fx.set_ship_visible(true)
	cam.snap()
	_set_theme_immediate(DIFFICULTY.theme_for(start_distance))
	world.reset_physics_interpolation()


var _follower: RouteFollower


func _enter_menu() -> void:
	get_tree().paused = false
	_reset_world(_next_seed())
	ship.follower = _follower
	ship.invulnerable = true
	input.reset()
	ui.show_screen("menu")
	Sfx.set_ambient(true)
	ui.set_menu_stats(int(Save.data["best_score"]), int(Save.data["credits"]))


func _go_menu() -> void:
	if session.state == RunSession.State.PAUSED or session.state == RunSession.State.RESULTS:
		session.transition(RunSession.State.MENU)
	_enter_menu()


func _start_run() -> void:
	if session.state == RunSession.State.PAUSED:
		session.transition(RunSession.State.MENU)
	if session.state == RunSession.State.RESULTS:
		session.transition(RunSession.State.MENU)
	get_tree().paused = false
	var tutorial := not bool(Save.data["tutorial_done"]) and allow_tutorial
	# first run: a longer safe opening teaches steering before any hazard
	_reset_world(_next_seed(), 0.0, 4 if tutorial else 2)
	if not session.start_run(tutorial):
		return
	ship.follower = _follower if autopilot_runs else null
	ship.invulnerable = invulnerable_runs
	ship.forward_speed = cfg.countdown_speed
	survived_cap = false
	input.reset()
	input.touched_this_run = false
	ui.show_screen("hud")
	ui.show_hint(tutorial)
	_tutorial_t = 0.0
	_countdown_t = 0.0
	_countdown_step = 0
	if tutorial:
		ui.banner("SECTOR 1  -  %s" % THEMES[0].display_name)
	run_started.emit(session.run_id)


func _pause() -> void:
	if session.pause():
		get_tree().paused = true
		input.reset()
		Sfx.set_flight(0.0, false)
		ui.show_screen("pause")


func _resume() -> void:
	if session.resume():
		get_tree().paused = false
		input.reset()
		ui.show_screen("hud")


func _on_state_changed(_prev: int, cur: int) -> void:
	Sfx.set_ambient(cur in [RunSession.State.MENU, RunSession.State.RESULTS, RunSession.State.PAUSED])


func _next_seed() -> int:
	if force_seed >= 0:
		return force_seed + session.run_id
	return SeedService.fresh_seed()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if session.state in [RunSession.State.RUNNING, RunSession.State.COUNTDOWN, RunSession.State.TUTORIAL] and pause_on_focus_loss:
				_pause()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if input:
				input.reset()


func _unhandled_input(event: InputEvent) -> void:
	# (pause / resume toggling lives in GameUI, which keeps processing while paused)
	if event.is_action_pressed("roll_left"):
		_try_roll(-1)
	elif event.is_action_pressed("roll_right"):
		_try_roll(1)
	elif event.is_action_pressed("launch"):
		if session.state == RunSession.State.MENU or session.state == RunSession.State.RESULTS:
			_start_run()


# --- per-frame gameplay ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var st := session.state
	match st:
		RunSession.State.MENU:
			ship.forward_speed = cfg.attract_speed
			ship.step(delta)
		RunSession.State.COUNTDOWN:
			_countdown(delta)
			ship.step(delta)
		RunSession.State.TUTORIAL, RunSession.State.RUNNING:
			_run_step(delta)
		RunSession.State.CRASHED:
			_crash_step(delta)
		_:
			pass

	if ship.position.z < -ORIGIN_SHIFT_AT:
		_shift_origin(-ship.position.z)
	director.update_for_ship(ship.position.z, 1)
	_update_theme(delta)
	if ship.alive:
		fx.sample_trails()
	var speed_t := cfg.speed_t(ship.forward_speed)
	cam.update_camera(delta, speed_t)
	var flying := ship.alive
	fx.update_fx(speed_t, flying, delta, ship.lateral_vel.x / cfg.max_lateral_speed, absf(ship.visual.rotation.z) if ship.visual else 0.0)
	ui.set_roll_ready(ship.roll_ready())
	if high_quality:
		post_mat.set_shader_parameter("intensity", speed_t * (0.35 if reduced_motion else 1.0) if flying else 0.0)
		_flash = move_toward(_flash, 0.0, delta * 3.0)
		post_mat.set_shader_parameter("flash", _flash)
		post_mat.set_shader_parameter("flash_color", _flash_color)
	Sfx.set_flight(speed_t, flying and st != RunSession.State.PAUSED)
	if Time.get_ticks_msec() > _hitstop_until and Engine.time_scale < time_base and st != RunSession.State.CRASHED:
		Engine.time_scale = time_base


func _countdown(delta: float) -> void:
	_countdown_t += delta
	var step := int(_countdown_t / 0.5)
	if step != _countdown_step or _countdown_t == delta:
		_countdown_step = step
		if step < 3:
			ui.set_countdown(str(3 - step))
			Sfx.play("beep")
		else:
			ui.set_countdown("GO")
			Sfx.play("go")
			session.transition(RunSession.State.RUNNING)


func _run_step(delta: float) -> void:
	var target_speed := director.speed_at(ship.distance_travelled)
	if session.state == RunSession.State.TUTORIAL:
		target_speed = cfg.base_speed
		_tutorial_t += delta
		if input.touched_this_run:
			ui.show_hint(false)
		if input.touched_this_run and _tutorial_t > 4.0:
			session.transition(RunSession.State.RUNNING)
	ship.forward_speed = move_toward(ship.forward_speed, target_speed, delta * 20.0)
	if not ship.step(delta):
		return
	score.distance = ship.distance_travelled
	score.tick(delta)
	if score.distance >= distance_cap:
		survived_cap = true
		ship.alive = false
		_on_crash(null)
		return
	for ev in sensor.update(ship.position, director.plans):
		_on_near_miss(ev)
	_collect_pickups()
	ui.set_hud(score.score(), score.distance, ship.forward_speed, score.combo, score.combo_timer / cfg.combo_timeout, cfg.speed_t(ship.forward_speed))


func _try_roll(dir: int) -> void:
	if session.is_live():
		ship.roll(dir)


func _on_rolled(dir: int) -> void:
	Sfx.play("whoosh", 1.35, -1.0)
	cam.add_kick(4.0)
	cam.add_shake(0.12)
	_vibrate(12)


func _on_near_miss(ev: Dictionary) -> void:
	var pts := score.register_near_miss()
	hazard_passed.emit(session.run_id, int(ev["uid"]), pts)
	var color := GameUI.CYAN.lerp(GameUI.PINK, float(score.combo - 1) / maxf(cfg.combo_max - 1, 1))
	var label := "NEAR MISS" if score.combo < 3 else ("RAZOR!" if score.combo < cfg.combo_max else "INSANE!")
	if ship.rolling:
		label = "ROLL DODGE!"
		color = GameUI.GOLD
	ui.popup("%s  +%d" % [label, pts], color)
	burst.near_miss(ev["point"], color)
	cam.add_kick(5.0 + score.combo)
	cam.add_shake(0.25)
	_flash = 0.12
	_flash_color = color
	Sfx.play("whoosh", 0.9 + 0.08 * score.combo)
	_vibrate(18)
	if not reduced_motion:
		Engine.time_scale = time_base * 0.8
		_hitstop_until = Time.get_ticks_msec() + 90


func _collect_pickups() -> void:
	var sp := ship.global_position
	for p in director.plans:
		var plan := p as ChunkPlan
		if plan.root == null or sp.z > plan.z_start + 5.0 or sp.z < plan.z_end() - 5.0:
			continue
		for orb in plan.pickup_nodes.duplicate():
			if (orb as Node3D).global_position.distance_to(sp) < 2.0:
				score.orbs += 1
				dresser.collect_orb(plan, orb)
				Sfx.play("chime", 1.0 + 0.05 * (score.orbs % 8))


func _on_crash(collider: Object) -> void:
	var hazard := "debris"
	if collider is ObstacleNode:
		hazard = (collider as ObstacleNode).hazard_name
	if not session.crash(score.score()):
		return
	_crash_reason = "You clipped %s at %d km/h" % [hazard, int(ship.forward_speed * 3.6)]
	burst.explode(ship.global_position, ship_parts["accent"])
	ship.visual.visible = false
	fx.set_ship_visible(false)
	cam.add_shake(1.6)
	_flash = 0.6
	_flash_color = Color(1.0, 0.6, 0.35)
	ui.flash(Color(1.0, 0.6, 0.4), 0.0 if high_quality else 0.5)
	Sfx.cut_flight()
	Sfx.play("boom", 1.0, -4.0)
	_vibrate(140)
	Engine.time_scale = time_base * (0.6 if reduced_motion else 0.3)
	_crash_real_t = 0.0
	run_ended.emit(session.run_id, score.score(), _crash_reason)


func _crash_step(delta: float) -> void:
	_crash_real_t += delta / maxf(Engine.time_scale, 0.001) * time_base
	ship.forward_speed = move_toward(ship.forward_speed, 0.0, delta * 60.0)
	if _crash_real_t > crash_delay:
		Engine.time_scale = time_base
		_finish_run()


func _finish_run() -> void:
	var s := score.score()
	var credits := score.credits_earned()
	var best_before := int(Save.data["best_score"])
	var new_best := s > best_before
	Save.data["best_score"] = maxi(best_before, s)
	Save.data["best_distance"] = maxi(int(Save.data["best_distance"]), int(score.distance))
	Save.data["total_runs"] = int(Save.data["total_runs"]) + 1
	Save.data["tutorial_done"] = true
	# The reward ledger is the only thing that changes the wallet.
	if Save.grant_reward("run:%d:%d" % [_run_seed, session.run_id], credits):
		reward_earned.emit(session.run_id, credits)
	session.transition(RunSession.State.RESULTS)
	ui.show_results(s, score.distance, score.near_miss_count, credits, _crash_reason, new_best, int(Save.data["best_score"]))


func _shift_origin(dz: float) -> void:
	ship.position.z += dz
	director.shift_origin(dz)
	fx.shift(dz)
	burst.shift(dz)
	cam.global_position.z += dz
	world.reset_physics_interpolation()


func _vibrate(ms: int) -> void:
	if haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
