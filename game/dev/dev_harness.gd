extends Node
## Dev / test harness, driven by command-line flags passed after `--`.
## It is the project's test harness: keep it in the codebase (see README "Dev flags").
##
##   --fresh            use a throw-away save (deleted on exit); never touches the real save
##   --save=PATH        use this save file instead (for save -> reload checks)
##   --autotest         play the game automatically: real UI clicks, drag steering, autopilot
##                      flight through every progression stage, crash, results, hangar purchase,
##                      settings, retry. One "[autotest] ..." line per stage, quits with 0/1.
##   --until=N|NAME     stop the autotest after that stage (index or name)
##   --no-warp          autotest flies every metre instead of fast-forwarding between stages
##   --shot=PATH        save a viewport screenshot and quit (after --state / --until is reached)
##   --shots=DIR        timeline tour: menu, all three sectors, crash, results (alias --capture=DIR)
##   --state=NAME       menu | tutorial | countdown | hud | pause | settings | hangar | results
##                      | roll (mid barrel roll; --roll-at=0..1, --roll-dir=-1|1) | bank (hard turn)
##   --distance=M       start runs at this route distance (pick a sector / difficulty band)
##   --seed=N           deterministic run seeds
##   --livery=ID        nova | ember | phantom
##   --quality=low|high, --reduced-motion, --invert-y
##   --autopilot        runs are flown by the RouteFollower (invulnerable unless --soak)
##   --soak=N           N run/retry cycles with the physics autopilot, pool leak check
##   --soak-distance=M  distance that counts as a survived soak run (default 2500)
##   --tilt             tilt steering setting on (with no sensor: falls back to touch)
##   --fake-tilt=P,R    simulate a phone held at pitch P deg, rolled R deg (desktop testing of tilt)

## Built in setup(): fixed head/tail plus one milestone per difficulty band
## and per world (sector), in distance order, then a loop back to world 1.
var STAGES: Array[String] = []
var _milestones: Array = []  # [name, distance, note]

var game: Node  # run_root
var flags: Dictionary = {}
var fresh: bool = false
var _save_files: Array[String] = []
var _passes: int = 0
var _fails: int = 0
var _t0: int = 0
var _until: int = 999
var _soak_log: Array = []
var _soak_target: int = 0
var _soak_distance: float = 2500.0
var _warp_count: int = 0


func setup(p_game: Node) -> void:
	game = p_game
	_build_stages()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			flags[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if flags.has("capture"):
		flags["shots"] = flags["capture"]
	if flags.is_empty():
		return
	var automated := flags.has("autotest") or flags.has("shots") or flags.has("soak") or flags.has("shot") or flags.has("state")
	if flags.has("save"):
		_use_save(str(flags["save"]), false)
	elif flags.has("fresh") or automated:
		fresh = true
		_use_save("user://dev_fresh_save.json", true)
	if flags.has("seed"):
		game.force_seed = int(flags["seed"])
	elif automated:
		game.force_seed = 1234
	var s: Dictionary = Save.data["settings"]
	if flags.has("quality"):
		s["quality"] = str(flags["quality"])
	if flags.has("reduced-motion"):
		s["reduced_motion"] = true
	if flags.has("invert-y"):
		s["invert_y"] = true
	if flags.has("livery") and ShipBuilder.LIVERIES.has(str(flags["livery"])):
		var id := str(flags["livery"])
		Save.data["livery"] = id
		if not id in Save.data["unlocked_liveries"]:
			(Save.data["unlocked_liveries"] as Array).append(id)
		game._build_ship(id)
	if automated:
		game.pause_on_focus_loss = false
	if flags.has("legacy-steer"):
		game.cfg.smooth_steering = false
	# tuning overrides for HandlingConfig smoothing (used with --trace-steer)
	for key in ["brake_factor", "steer_jerk", "steer_response", "input_smooth_min", "input_smooth_max"]:
		if flags.has(key):
			game.cfg.set(key, float(flags[key]))
	if flags.has("tilt"):
		Save.data["settings"]["tilt"] = true
	if flags.has("fake-tilt"):
		var pr := str(flags["fake-tilt"]).split(",")
		game.tilt.override_gravity = TiltInput.simulated_gravity(float(pr[0]), float(pr[1]) if pr.size() > 1 else 0.0)
		Save.data["settings"]["tilt"] = true
	if flags.has("autopilot"):
		game.autopilot_runs = true
		game.invulnerable_runs = true
	if flags.has("until"):
		var u := str(flags["until"])
		_until = int(u) if u.is_valid_int() else maxi(STAGES.find(u), 0)
	if flags.has("soak"):
		_soak_target = int(flags["soak"])
		_soak_distance = float(flags.get("soak-distance", "2500"))
		game.autopilot_runs = true
		game.invulnerable_runs = false
		game.allow_tutorial = false
		game.crash_delay = 0.05
		game.distance_cap = _soak_distance
		game.session.state_changed.connect(_on_soak_state)
		_start_soak.call_deferred()
	elif flags.has("perf"):
		_perf.call_deferred()
	elif flags.has("trace-steer"):
		_trace_steer.call_deferred()
	elif flags.has("autotest"):
		_autotest.call_deferred()
	elif flags.has("shots"):
		_tour.call_deferred()
	elif flags.has("shot") or flags.has("state"):
		_single_state.call_deferred()


func _build_stages() -> void:
	var diff: DifficultyProfile = game.DIFFICULTY
	_milestones.clear()
	for b in range(2, diff.band_distances.size()):
		_milestones.append(["band%d" % b, diff.band_distances[b] + 20.0, ""])
	for w in range(1, diff.theme_count):
		_milestones.append(["sector%d" % (w + 1), w * diff.theme_length + 180.0, game.THEMES[w].display_name])
	_milestones.append(["loop", diff.theme_count * diff.theme_length + 180.0, game.THEMES[0].display_name])
	_milestones.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	STAGES.assign(["boot", "launch", "steer", "roll", "running", "band1", "pause"])
	for m in _milestones:
		STAGES.append(m[0])
	STAGES.append_array(["crash", "results", "hangar", "settings", "retry", "tilt"])
	_until = STAGES.size() - 1


func _si(stage_name: String) -> int:
	return STAGES.find(stage_name)


# --- save isolation ----------------------------------------------------------------

func _use_save(path: String, wipe: bool) -> void:
	Save.path = path
	_save_files = [path, path + ".bak", path + ".tmp"]
	if wipe:
		_delete_save_files()
	Save.load_save()


func _delete_save_files() -> void:
	for f in _save_files:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func finish(code: int) -> void:
	if fresh:
		_delete_save_files()
	Engine.physics_ticks_per_second = 60
	game.get_tree().paused = false
	Engine.time_scale = 1.0
	game.get_tree().quit(code)


# --- helpers ---------------------------------------------------------------------------

func _fast_forward() -> void:
	# Headless has no frame cap, so a higher time scale simply runs faster than real time.
	# Godot scales the physics step by time_scale, so raise the tick rate by the same
	# factor: every physics step stays exactly 1/60 s and the flight model is unchanged.
	if DisplayServer.get_name() == "headless":
		var ff := 6.0
		game.time_base = ff
		Engine.physics_ticks_per_second = int(60 * ff)
		Engine.max_physics_steps_per_frame = 32
		Engine.time_scale = ff


func _frames(n: int) -> void:
	for i in n:
		await game.get_tree().process_frame


## Waits (in game seconds) until cond() is true. Returns false on timeout.
func _wait(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		await game.get_tree().process_frame
		t += game.get_process_delta_time() if not game.get_tree().paused else 1.0 / 60.0
		if t > timeout * maxf(game.time_base, 1.0):
			return false
	return true


func _screen_pos(c: Control) -> Vector2:
	var center := c.get_global_transform_with_canvas() * (c.size * 0.5)
	return c.get_viewport().get_screen_transform() * center


## A real mouse click (press + release) at the control's centre. With touch emulation
## this is exactly what a tap on a phone turns into.
func click(c: Control) -> void:
	var pos := _screen_pos(c)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await _frames(2)


func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)


func touch(pressed: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = pos
	Input.parse_input_event(e)


func drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	Input.parse_input_event(e)


func status(stage: int, ok: bool, note: String = "") -> void:
	var g := game
	var theme_name: String = g.THEMES[maxi(g.current_theme, 0)].display_name
	print("[autotest] stage=%d name=%s %s state=%s dist=%d score=%d combo=%d near=%d orbs=%d speed=%.1f sector=\"%s\" credits=%d chunks=%d pool_active=%d t=%.1fs%s" % [
		stage, STAGES[stage], "OK" if ok else "FAIL", RunSession.state_name(g.session.state),
		int(g.score.distance), g.score.score(), g.score.combo, g.score.near_miss_count, g.score.orbs,
		g.ship.forward_speed, theme_name, int(Save.data["credits"]), g.director.plans.size(),
		g.dresser.pool.active_count, (Time.get_ticks_msec() - _t0) / 1000.0, ("  " + note) if note != "" else ""])
	if ok:
		_passes += 1
	else:
		_fails += 1


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := game.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[shot] ", path)


## Jumps the route forward (fast-forward) and lets the ship fly the last stretch for real.
func _warp_to(d: float) -> void:
	_warp_count += 1
	var g := game
	g.director.reset(maxi(g.force_seed, 0) + 7919 * _warp_count, g.ship.position.z, d, 1)
	g.ship.distance_travelled = d
	g.ship.forward_speed = g.director.speed_at(d)
	g.score.distance = d
	g._set_theme_immediate(g.DIFFICULTY.theme_for(d))
	g.fx.clear_trails()


func _fly_to(d: float) -> bool:
	var g := game
	if not flags.has("no-warp") and g.ship.distance_travelled < d - 450.0:
		_warp_to(d - 450.0)
	return await _wait(func() -> bool: return g.ship.distance_travelled >= d or not g.session.is_live(), 240.0) and g.session.is_live()


func _stop_if_until(stage: int) -> bool:
	if stage < _until:
		return false
	if flags.has("shot"):
		await _frames(3)
		await _shot(str(flags["shot"]))
	print("[autotest] stopped at --until=%s (%d passed, %d failed)" % [STAGES[stage], _passes, _fails])
	finish(1 if _fails > 0 else 0)
	return true


# --- autotest --------------------------------------------------------------------------

func _autotest() -> void:
	_t0 = Time.get_ticks_msec()
	var g := game
	var ui: GameUI = g.ui
	_fast_forward()
	print("[autotest] begin seed=%d warp=%s renderer=%s" % [g.force_seed, str(not flags.has("no-warp")), RenderingServer.get_current_rendering_method()])
	await _frames(10)

	# 0 boot
	status(_si("boot"), g.session.state == RunSession.State.MENU and ui.menu.visible)
	if await _stop_if_until(_si("boot")): return

	# 1 launch: tap the screen like a player
	await click(ui.buttons["menu:tap"])
	var first_run: bool = g.session.state == RunSession.State.TUTORIAL
	status(_si("launch"), first_run or g.session.state == RunSession.State.COUNTDOWN, "tutorial=%s" % first_run)
	if await _stop_if_until(_si("launch")): return

	# 2 steer: one-thumb relative drag through the input router
	# drag exactly 4 m worth (drag_gain metres per viewport height), in screen pixels
	var vp: Viewport = g.get_viewport()
	var vsize: Vector2 = vp.get_visible_rect().size
	var tf: Transform2D = vp.get_screen_transform()
	var c: Vector2 = tf * (vsize * 0.5)
	var c2: Vector2 = tf * (vsize * 0.5 + Vector2(vsize.y * 4.0 / g.cfg.drag_gain, 0.0))
	touch(true, c)
	await _frames(2)
	drag(c2)
	await _wait(func() -> bool: return g.ship.position.x > 3.5, 3.0)
	var steered: float = g.ship.position.x
	drag(c)
	touch(false, c)
	status(_si("steer"), steered > 3.5, "4 m drag moved ship to x=%.2f" % steered)
	if await _stop_if_until(_si("steer")): return

	# 3 roll: on-screen roll button (real click), full revolution + sidestep, cooldown, Q key
	g.ship.target = Vector2.ZERO
	await _wait(func() -> bool: return absf(g.ship.position.x) < 0.3, 3.0)
	var x0: float = g.ship.position.x
	await click(ui.buttons["hud:roll_right"])
	var started: bool = g.ship.rolling and g.ship.roll_dir == 1
	var min_angle := 0.0
	var t_roll := 0.0
	while g.ship.rolling and t_roll < 2.0:
		min_angle = minf(min_angle, g.ship.roll_angle)
		await g.get_tree().process_frame
		t_roll += g.get_process_delta_time()
	await _wait(func() -> bool: return absf(g.ship.position.x - g.ship.target.x) < 0.3, 2.0)
	var moved: float = g.ship.position.x - x0
	var blocked: bool = not g.ship.roll(-1)  # still cooling down
	await _wait(func() -> bool: return g.ship.roll_ready() >= 1.0, 3.0)
	await key(KEY_Q)
	var q_roll: bool = g.ship.rolling and g.ship.roll_dir == -1
	await _wait(func() -> bool: return not g.ship.rolling, 2.0)
	var full_turn := min_angle < -TAU * 0.9
	status(_si("roll"), started and full_turn and moved > 3.5 and blocked and q_roll, "button roll=%s turn=%.0fdeg sidestep=%.2fm cooldown_blocks=%s Q_roll=%s" % [started, rad_to_deg(-min_angle), moved, blocked, q_roll])
	if await _stop_if_until(_si("roll")): return

	# 4 running: autopilot takes over from here (route-following, NOT invulnerable)
	g.ship.follower = g._follower
	g.ship.invulnerable = false
	var running := await _wait(func() -> bool: return g.session.state == RunSession.State.RUNNING, 20.0)
	status(_si("running"), running)
	if await _stop_if_until(_si("running")): return

	# 4 band 1
	status(_si("band1"), await _fly_to(g.DIFFICULTY.band_distances[1] + 20.0))
	if await _stop_if_until(_si("band1")): return

	# 5 pause / resume via the HUD buttons
	await click(ui.buttons["hud:II"])
	var paused: bool = g.session.state == RunSession.State.PAUSED and g.get_tree().paused and ui.pause_panel.visible
	await click(ui.buttons["pause:RESUME"])
	var resumed: bool = g.session.state == RunSession.State.RUNNING and not g.get_tree().paused
	# keyboard / Android-back path: Esc pauses, Esc again resumes (must work while paused)
	await key(KEY_ESCAPE)
	var esc_paused: bool = g.session.state == RunSession.State.PAUSED
	await key(KEY_ESCAPE)
	var esc_resumed: bool = g.session.state == RunSession.State.RUNNING and not g.get_tree().paused
	status(_si("pause"), paused and resumed and esc_paused and esc_resumed, "buttons paused=%s resumed=%s, esc paused=%s resumed=%s" % [paused, resumed, esc_paused, esc_resumed])
	if await _stop_if_until(_si("pause")): return

	# 6-10 progression: difficulty bands and sectors
	for ms in _milestones:
		var ok: bool = await _fly_to(float(ms[1]))
		var expect_theme: int = g.DIFFICULTY.theme_for(float(ms[1]))
		# worlds switch at the first chunk past the boundary, so only sector checkpoints assert the world
		if str(ms[0]).begins_with("sector") or ms[0] == "loop":
			ok = ok and g.current_theme == expect_theme
		var world: String = g.THEMES[g.current_theme].display_name
		status(_si(ms[0]), ok, ("world=\"%s\"" % world) if str(ms[0]).begins_with("sector") or ms[0] == "loop" else "")
		if not ok:
			print("[autotest] run ended early: ", g._crash_reason)
			finish(1)
			return
		if await _stop_if_until(_si(ms[0])): return

	# 11 crash: hands off the controls and fly straight until something is hit
	var credits_before := int(Save.data["credits"])
	g.ship.follower = null
	g.ship.target = Vector2(g.ship.position.x, g.ship.position.y)
	var crashed := await _wait(func() -> bool: return not g.session.is_live(), 60.0)
	status(_si("crash"), crashed, "reason=\"%s\"" % g._crash_reason)
	if await _stop_if_until(_si("crash")): return

	# 12 results + reward ledger
	var at_results := await _wait(func() -> bool: return g.session.state == RunSession.State.RESULTS, 10.0)
	var earned: int = g.score.credits_earned()
	status(_si("results"), at_results and ui.results.visible and int(Save.data["credits"]) == credits_before + earned, "earned=%d" % earned)
	if await _stop_if_until(_si("results")): return

	# 13 hangar: back to menu, open hangar, buy + equip the next livery if affordable
	await click(ui.buttons["results:MENU"])
	await click(ui.buttons["menu:HANGAR"])
	await click(ui.buttons["hangar:>"])
	var cost := int(ShipBuilder.LIVERIES["ember"]["cost"])
	var refused_ok := true
	var note := ""
	if int(Save.data["credits"]) < cost:
		# prove the refusal path first: the UNLOCK button must not spend anything
		var have := int(Save.data["credits"])
		await click(ui.buttons["hangar:action"])
		refused_ok = Save.data["livery"] == "nova" and int(Save.data["credits"]) == have
		# then top up through the real reward ledger (dev-only grant) to exercise the purchase
		Save.grant_reward("dev:autotest:%d" % g.session.run_id, cost - have)
		ui.refresh_hangar()
		note = "refused at %d/%d, dev grant +%d; " % [have, cost, cost - have]
	var before := int(Save.data["credits"])
	await click(ui.buttons["hangar:action"])
	var bought: bool = Save.data["livery"] == "ember" and "ember" in Save.data["unlocked_liveries"] and int(Save.data["credits"]) == before - cost
	status(_si("hangar"), ui.hangar_panel.visible and refused_ok and bought, note + ("bought + equipped EMBER for %d" % cost if bought else "purchase failed"))
	await click(ui.buttons["hangar:BACK"])
	if await _stop_if_until(_si("hangar")): return

	# 14 settings: toggle reduced motion with a real click, verify, toggle back
	await click(ui.buttons["menu:SETTINGS"])
	var toggle: CheckButton = ui.buttons["settings:reduced_motion"]
	await click(toggle)
	var on: bool = Save.setting("reduced_motion") == true and g.cam.reduced_motion
	await click(toggle)
	var off: bool = Save.setting("reduced_motion") == false and not g.cam.reduced_motion
	var tilt_toggle: CheckButton = ui.buttons["settings:tilt"]
	await click(tilt_toggle)
	var tilt_on: bool = Save.setting("tilt") == true and g.tilt.enabled
	status(_si("settings"), ui.settings_panel.visible and on and off and tilt_on, "reduced motion on/off, tilt switched on=%s" % tilt_on)
	await click(ui.buttons["settings:DONE"])
	if await _stop_if_until(_si("settings")): return

	g.tilt.override_gravity = TiltInput.simulated_gravity(30.0, 0.0)
	# 15 retry: second launch skips the tutorial and goes through the countdown
	await click(ui.buttons["menu:tap"])
	var countdown: bool = g.session.state == RunSession.State.COUNTDOWN
	var live := await _wait(func() -> bool: return g.session.state == RunSession.State.RUNNING, 10.0)
	status(_si("retry"), countdown and live and ui.hud.visible)
	if await _stop_if_until(_si("retry")): return

	# tilt: simulated sensor - roll right/left, pitch away, then recalibrate via the pause menu
	g.ship.invulnerable = true
	var hold := 30.0
	g.tilt.override_gravity = TiltInput.simulated_gravity(hold, 15.0)
	var went_right := await _wait(func() -> bool: return g.ship.position.x > 3.5, 3.0)
	g.tilt.override_gravity = TiltInput.simulated_gravity(hold, -15.0)
	var went_left := await _wait(func() -> bool: return g.ship.position.x < -3.5, 3.0)
	g.tilt.override_gravity = TiltInput.simulated_gravity(hold + 12.0, 0.0)
	var went_down := await _wait(func() -> bool: return g.ship.position.y < -1.5, 3.0)
	# player now holds the phone rolled 15 deg right: recalibrate makes that neutral
	g.tilt.override_gravity = TiltInput.simulated_gravity(hold, 15.0)
	await click(ui.buttons["hud:II"])
	var recal_visible: bool = ui.buttons["pause:RECALIBRATE TILT"].visible
	await click(ui.buttons["pause:RECALIBRATE TILT"])
	await click(ui.buttons["pause:RESUME"])
	var centered := await _wait(func() -> bool: return absf(g.ship.position.x) < 0.8 and absf(g.ship.position.y) < 0.8, 3.0)
	g.tilt.override_gravity = Vector3.ZERO
	status(_si("tilt"), went_right and went_left and went_down and recal_visible and centered, "right=%s left=%s down=%s recalibrate_button=%s recentred=%s" % [went_right, went_left, went_down, recal_visible, centered])
	await _stop_if_until(_si("tilt"))


# --- performance profile ---------------------------------------------------------

## Flies each world for N seconds (autopilot) and reports frame time, draw calls,
## primitives, CPU script time and chunk-planning spikes. Use under a real
## renderer (Xvfb + lavapipe): software rasterisation makes frame time scale
## with shading work, a useful proxy for mobile GPU cost.
func _perf() -> void:
	var g := game
	var secs := float(flags.get("perf", "6"))
	Save.data["tutorial_done"] = true
	g.autopilot_runs = true
	g.invulnerable_runs = true
	g._start_run()
	await _wait(func() -> bool: return g.session.state == RunSession.State.RUNNING, 10.0)
	var diff: DifficultyProfile = g.DIFFICULTY
	var rows: PackedStringArray = []
	var all_ft: Array = []
	for w in diff.theme_count:
		_warp_to(w * diff.theme_length + 250.0)
		await _frames(30)  # settle after warp
		g.director.plan_usec_max = 0
		g.director.main_usec_max = 0
		var ft: Array = []
		var dc := 0.0
		var prims := 0.0
		var objs := 0.0
		var proc := 0.0
		var phys := 0.0
		var n := 0
		var t := 0.0
		var last := Time.get_ticks_usec()
		while t < secs:
			await g.get_tree().process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			t += ms / 1000.0
			ft.append(ms)
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			n += 1
		ft.sort()
		all_ft.append_array(ft)
		var avg := 0.0
		for v in ft:
			avg += v
		avg /= maxf(ft.size(), 1)
		rows.append("[perf] %-15s frames=%4d avg=%6.1fms p95=%6.1fms fps=%5.1f draws=%5.0f prims=%7.0fk objs=%4.0f cpu_process=%5.2fms cpu_physics=%5.2fms plan_max=%5.1fms main_director_max=%5.1fms" % [
			g.THEMES[w].display_name, n, avg, ft[int(ft.size() * 0.95)], 1000.0 / avg, dc / n, prims / n / 1000.0, objs / n, proc / n, phys / n, g.director.plan_usec_max / 1000.0, g.director.main_usec_max / 1000.0])
	for r in rows:
		print(r)
	all_ft.sort()
	var tot := 0.0
	for v in all_ft:
		tot += v
	print("[perf] OVERALL avg=%.1fms p95=%.1fms fps=%.1f  plan avg=%.2fms (n=%d)" % [tot / all_ft.size(), all_ft[int(all_ft.size() * 0.95)], 1000.0 * all_ft.size() / tot, g.director.plan_usec_total / 1000.0 / maxi(g.director.plan_count, 1), g.director.plan_count])
	finish(0)


# --- steering trace (smoothness measurement) -------------------------------------

var _trace_rows: PackedStringArray = PackedStringArray()
var _tracing: bool = false
var _trace_t: float = 0.0


func _physics_process(delta: float) -> void:
	if not _tracing:
		return
	var sh: FlightController = game.ship
	_trace_t += delta
	var a: float = (sh.lateral_vel.x - float(get_meta("pv", 0.0))) / delta
	set_meta("pv", sh.lateral_vel.x)
	_trace_rows.append("%.4f,%.4f,%.4f,%.4f,%.3f,%.3f" % [_trace_t, sh.target.x, sh._target_f.x, sh.position.x, sh.lateral_vel.x, a])


## Scripted touch drags (step moves + a jittery hold), logged every physics frame.
func _trace_steer() -> void:
	var g := game
	Save.data["tutorial_done"] = true
	g.invulnerable_runs = true
	g._start_run()
	await _wait(func() -> bool: return g.session.state == RunSession.State.RUNNING, 10.0)
	var vp: Viewport = g.get_viewport()
	var vsize: Vector2 = vp.get_visible_rect().size
	var tf: Transform2D = vp.get_screen_transform()
	var m2px: float = vsize.y / float(g.cfg.drag_gain)
	var c := vsize * 0.5
	touch(true, tf * c)
	await _frames(3)
	_tracing = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# metres of drag at each segment; last segment adds +-4 px touch noise
	for seg in [[4.0, 1.0, 0.0], [-4.0, 1.0, 0.0], [0.0, 0.8, 0.0], [1.5, 0.8, 0.0], [1.5, 1.2, 4.0]]:
		var t := 0.0
		while t < float(seg[1]):
			var jitter := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * float(seg[2])
			drag(tf * (c + Vector2(float(seg[0]) * m2px, 0.0) + jitter))
			await g.get_tree().process_frame
			t += g.get_process_delta_time()
	_tracing = false
	var f := FileAccess.open(str(flags["trace-steer"]), FileAccess.WRITE)
	f.store_string("t,target,target_filtered,x,vx,ax\n" + "\n".join(_trace_rows) + "\n")
	f.close()
	print("[trace] %d samples -> %s (smooth_steering=%s)" % [_trace_rows.size(), flags["trace-steer"], g.cfg.smooth_steering])
	finish(0)


# --- single state for a screenshot -----------------------------------------------------

func _single_state() -> void:
	var g := game
	var st := str(flags.get("state", "menu"))
	var d := float(flags.get("distance", "0"))
	g.autopilot_runs = true
	g.invulnerable_runs = true
	if st != "tutorial":
		Save.data["tutorial_done"] = true
	await _frames(5)
	match st:
		"settings", "hangar":
			g.ui.show_screen(st)
		"tutorial", "countdown", "hud", "pause", "results", "roll", "bank":
			g._start_run()
			if d > 0.0:
				_warp_to(d)
			if st == "countdown":
				await _frames(4)
			else:
				await _wait(func() -> bool: return g.session.is_live() and g.session.state != RunSession.State.COUNTDOWN, 10.0)
				await _wait(func() -> bool: return false, 2.5)  # let the flight settle
			if st == "pause":
				g._pause()
			elif st == "roll":
				g.ship.follower = null
				g.ship.roll(int(flags.get("roll-dir", "1")))
				var stop_at := float(flags.get("roll-at", "0.45"))
				await _wait(func() -> bool: return g.ship._roll_t >= stop_at * g.cfg.roll_duration, 2.0)
			elif st == "bank":
				g.ship.follower = null
				g.ship.target = Vector2(-7.5 if g.ship.position.x > 0.0 else 7.5, g.ship.position.y)
				await _wait(func() -> bool: return absf(g.ship.lateral_vel.x) > g.cfg.max_lateral_speed * 0.8, 2.0)
			elif st == "results":
				_crash_into_nearest()
				await _wait(func() -> bool: return g.session.state == RunSession.State.RESULTS, 10.0)
	if st not in ["roll", "bank"]:
		await _frames(20)
	if flags.has("shot"):
		await _shot(str(flags["shot"]))
		finish(0)


func _crash_into_nearest() -> void:
	var g := game
	var best: Node = null
	var best_d := INF
	var plan: ChunkPlan = g.director.plan_at(g.ship.position.z - 20.0)
	if plan and plan.root:
		for ch in plan.root.get_children():
			if ch is ObstacleNode and ch.visible:
				var dd: float = (ch as Node3D).global_position.distance_to(g.ship.global_position)
				if dd < best_d:
					best_d = dd
					best = ch
	g.ship.alive = false
	g._on_crash(best)


# --- timeline tour ------------------------------------------------------------------------

func _tour() -> void:
	var g := game
	var dir := str(flags["shots"])
	DirAccess.make_dir_recursive_absolute(dir)
	g.autopilot_runs = true
	g.invulnerable_runs = true
	# menu, then ~4.5 s in each of the six worlds (warping between them), crash, results
	var steps: Array = [[2.5, "shot", "01_menu"], [2.6, "start"]]
	var t := 2.6
	var diff: DifficultyProfile = g.DIFFICULTY
	for w in diff.theme_count:
		if w > 0:
			steps.append([t, "warp", w * diff.theme_length + 50.0])
		steps.append([t + 1.8, "roll", 1 if w % 2 == 0 else -1])
		steps.append([t + 3.6, "shot", "%02d_%s" % [w + 2, g.THEMES[w].display_name.to_lower().replace(" ", "_")]])
		t += 4.6
	steps.append([t, "crash"])
	steps.append([t + 0.15, "shot", "%02d_crash" % (diff.theme_count + 2)])
	steps.append([t + 2.9, "shot", "%02d_results" % (diff.theme_count + 3)])
	steps.append([t + 3.0, "quit"])
	var clock := 0.0
	while not steps.is_empty():
		await game.get_tree().process_frame
		clock += game.get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		while not steps.is_empty() and clock >= float(steps[0][0]):
			var step: Array = steps.pop_front()
			match str(step[1]):
				"shot":
					await _shot("%s/%s.png" % [dir, step[2]])
				"start":
					Save.data["tutorial_done"] = true
					g._start_run()
				"warp":
					_warp_to(float(step[2]))
				"roll":
					g.ship.roll(int(step[2]))
				"crash":
					_crash_into_nearest()
				"quit":
					finish(0)
					return


# --- soak ------------------------------------------------------------------------------

func _start_soak() -> void:
	_fast_forward()
	game._start_run()


func _on_soak_state(_prev: int, cur: int) -> void:
	if cur != RunSession.State.RESULTS:
		return
	var g := game
	var pool: NodePool = g.dresser.pool
	_soak_log.append({"survived": g.survived_cap, "created": pool.created_count})
	print("[soak] run %d: %s %d m, near misses %d, pool created %d active %d" % [g.session.run_id, "SURVIVED" if g.survived_cap else "CRASHED (" + g._crash_reason + ")", int(g.score.distance), g.score.near_miss_count, pool.created_count, pool.active_count])
	if _soak_log.size() < _soak_target:
		g._start_run.call_deferred()
		return
	var survived := 0
	for r in _soak_log:
		survived += int(r["survived"])
	var prewarm := {&"obs_0": 64, &"obs_1": 96, &"obs_2": 40, &"obs_3": 12, &"orbs": 8}
	print("[soak] SUMMARY: %d/%d runs reached %d m; pool created %d -> %d" % [survived, _soak_log.size(), int(_soak_distance), _soak_log[0]["created"], _soak_log[_soak_log.size() - 1]["created"]])
	print("[soak] pool created/peak per key: ", pool.stats())
	var leak_free := pool.leak_free(prewarm)
	print("[soak] pool leak-free: ", leak_free)
	finish.call_deferred(0 if survived == _soak_log.size() and leak_free else 2)
