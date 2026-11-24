extends SceneTree
## Drives the real main scene through the player flow with simulated touch:
## first-run tutorial -> drag steering -> RUNNING -> focus-loss pause ->
## resume (held touch cleared) -> crash -> RESULTS -> retry -> COUNTDOWN.
## Run: godot --headless --path . --script res://tests/flow_smoke.gd

var failures: int = 0


func check(cond: bool, label: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + label)
	if not cond:
		failures += 1


func _initialize() -> void:
	print("== flow smoke ==")
	var save: Node = root.get_node("Save")
	save.path = "user://flow_smoke_save.json"
	for f in [save.path, save.path + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	save.load_save()
	var main: Node = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	check(main.session.state == RunSession.State.MENU, "boots into MENU attract mode")
	main._start_run()
	check(main.session.state == RunSession.State.TUTORIAL, "first run starts the tutorial")
	Engine.time_scale = 4.0
	# touch and drag right
	_touch(true, Vector2(640, 400))
	await _frames(2)
	_drag(Vector2(760, 400))
	await _seconds(1.0)
	check(main.ship.position.x > 1.0, "relative drag steers the ship (x = %.2f)" % main.ship.position.x)
	_drag(Vector2(640, 400))
	await _seconds(0.8)
	# edge re-anchoring: reversing a drag that hit the envelope responds at once
	check(main.ship.position.x < 0.0, "reversing a drag at the edge responds immediately (x = %.2f)" % main.ship.position.x)
	_touch(false, Vector2(640, 400))
	main.ship.target = Vector2.ZERO  # harness: hold the centre line during the tutorial
	# focus loss pauses and clears held touches
	_touch(true, Vector2(640, 400))
	await _frames(2)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.session.state == RunSession.State.PAUSED and main.get_tree().paused, "focus loss pauses the run (state %s)" % RunSession.state_name(main.session.state))
	check(not main.input.active, "held touch cleared on pause")
	main._resume()
	check(main.session.state == RunSession.State.TUTORIAL and not main.get_tree().paused, "resume returns to the previous state")
	await _seconds(3.0)
	check(main.session.state == RunSession.State.RUNNING, "tutorial hands over to RUNNING after first steer")
	# fly hands-off until something is hit
	var t := 0.0
	while main.session.state == RunSession.State.RUNNING and t < 120.0:
		await process_frame
		t += 1.0 / 60.0
	check(main.session.state in [RunSession.State.CRASHED, RunSession.State.RESULTS], "hands-off flight eventually crashes")
	while main.session.state == RunSession.State.CRASHED and t < 140.0:
		await process_frame
		t += 1.0 / 60.0
	check(main.session.state == RunSession.State.RESULTS and main.ui.results.visible, "crash leads to RESULTS screen")
	check(str(main._crash_reason).begins_with("You clipped"), "failure reason shown: '%s'" % main._crash_reason)
	check(int(save.data["total_runs"]) == 1 and bool(save.data["tutorial_done"]), "run saved, tutorial marked done")
	var credits := int(save.data["credits"])
	main._on_crash(null)
	check(int(save.data["credits"]) == credits, "duplicate crash callback after results changes nothing")
	var t0 := Time.get_ticks_msec()
	main._start_run()
	check(main.session.state == RunSession.State.COUNTDOWN, "retry goes straight to COUNTDOWN (no tutorial)")
	print("  retry transition took %d ms" % (Time.get_ticks_msec() - t0))
	Engine.time_scale = 1.0
	print("== flow smoke: %s ==" % ("OK" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0 * Engine.time_scale


func _touch(pressed: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = pos
	Input.parse_input_event(e)


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	Input.parse_input_event(e)
