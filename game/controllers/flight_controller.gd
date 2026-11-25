class_name FlightController
extends CharacterBody3D
## Forward-auto, cross-section-constrained flight.
## Lateral / vertical velocity is acceleration limited toward a target point
## inside the bounded envelope. The visual mesh banks independently; there is
## no six-degree-of-freedom rigid body flight. move_and_collide sweeps the
## collision shape between the previous and new position each step, so thin
## obstacles cannot be tunnelled through at top speed.

signal crashed(collider: Object)
signal rolled(dir: int)

var cfg: HandlingConfig
var input: InputRouter
var forward_speed: float = 35.0
var lateral_vel: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var invulnerable: bool = false
var steering_enabled: bool = true
var follower: RouteFollower = null
var _ff: Vector2 = Vector2.ZERO
var distance_travelled: float = 0.0
var alive: bool = true
var visual: Node3D
var invert_y: bool = false

var _anchor_ship: Vector2 = Vector2.ZERO
# barrel roll
var rolling: bool = false
var roll_dir: int = 0
var _roll_t: float = 0.0
var _roll_cd: float = 0.0
var roll_count: int = 0
# visual motion state (spring-driven tilt)
var _tilt: Vector3 = Vector3.ZERO
var _tilt_vel: Vector3 = Vector3.ZERO
var _prev_lat: Vector2 = Vector2.ZERO
var _hover_t: float = 0.0
var roll_angle: float = 0.0


func setup(p_cfg: HandlingConfig, p_input: InputRouter) -> void:
	cfg = p_cfg
	input = p_input
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = cfg.ship_radius
	shape.shape = sphere
	add_child(shape)
	if input:
		input.steer_started.connect(_on_steer_started)


func set_visual(v: Node3D) -> void:
	if visual:
		visual.queue_free()
	visual = v
	add_child(v)


func _on_steer_started() -> void:
	_anchor_ship = target


func reset_to(pos: Vector3) -> void:
	position = pos
	lateral_vel = Vector2.ZERO
	target = Vector2(pos.x, pos.y)
	_anchor_ship = target
	distance_travelled = 0.0
	alive = true
	rolling = false
	_roll_t = 0.0
	_roll_cd = 0.0
	roll_angle = 0.0
	_tilt = Vector3.ZERO
	_tilt_vel = Vector3.ZERO
	_prev_lat = Vector2.ZERO
	if visual:
		visual.rotation = Vector3.ZERO
		visual.visible = true


## 0..1: how ready the barrel roll is (1 = available).
func roll_ready() -> float:
	if rolling:
		return 0.0
	return 1.0 - clampf(_roll_cd / maxf(cfg.roll_cooldown, 0.001), 0.0, 1.0)


## Starts a barrel roll to the left (-1) or right (+1): a 360 deg roll that
## also sidesteps roll_shift metres with a temporary lateral boost.
func roll(dir: int) -> bool:
	if not alive or rolling or _roll_cd > 0.0 or dir == 0:
		return false
	rolling = true
	roll_dir = signi(dir)
	_roll_t = 0.0
	roll_count += 1
	var shifted := clamp_bounds(target + Vector2(cfg.roll_shift * roll_dir, 0.0))
	_anchor_ship += shifted - target
	target = shifted
	rolled.emit(roll_dir)
	return true


func clamp_bounds(v: Vector2) -> Vector2:
	return Vector2(clampf(v.x, -cfg.bounds_half_width, cfg.bounds_half_width), clampf(v.y, -cfg.bounds_half_height, cfg.bounds_half_height))


func _update_target(delta: float) -> void:
	_ff = Vector2.ZERO
	if follower != null:
		var res := follower.sample(position.z, forward_speed)
		target = clamp_bounds(res[0])
		_ff = res[1]
		return
	if not steering_enabled or input == null:
		return
	if input.active:
		var off := input.drag_offset()
		var ysign := 1.0 if invert_y else -1.0
		var desired := _anchor_ship + Vector2(off.x, off.y * ysign) * cfg.drag_gain
		var clamped := clamp_bounds(desired)
		# re-anchor at the edges so reversing direction responds instantly
		_anchor_ship += clamped - desired
		target = clamped
	var k := input.keyboard_axis()
	if k != Vector2.ZERO:
		var ysign2 := 1.0 if invert_y else -1.0
		target = clamp_bounds(target + Vector2(k.x, k.y * ysign2) * cfg.keyboard_speed * delta)
		_anchor_ship = target


## Advances one physics step. Returns false if the ship crashed.
func step(delta: float) -> bool:
	if not alive:
		return false
	_update_target(delta)
	if _roll_cd > 0.0:
		_roll_cd = maxf(_roll_cd - delta, 0.0)
	var boost_v := 1.0
	var boost_a := 1.0
	if rolling:
		_roll_t += delta
		boost_v = cfg.roll_speed_mult
		boost_a = cfg.roll_accel_mult
		if _roll_t >= cfg.roll_duration:
			rolling = false
			_roll_cd = cfg.roll_cooldown
	var pos2 := Vector2(position.x, position.y)
	var gain := follower.gain if follower != null else cfg.steer_response
	if rolling:
		gain *= 1.4
	var desired := (target - pos2) * gain + _ff
	var max_x := cfg.max_lateral_speed * boost_v
	desired.x = clampf(desired.x, -max_x, max_x)
	desired.y = clampf(desired.y, -cfg.max_vertical_speed, cfg.max_vertical_speed)
	lateral_vel.x = move_toward(lateral_vel.x, desired.x, cfg.lateral_accel * boost_a * delta)
	lateral_vel.y = move_toward(lateral_vel.y, desired.y, cfg.vertical_accel * delta)
	var motion := Vector3(lateral_vel.x, lateral_vel.y, -forward_speed) * delta
	var next := position + motion
	if absf(next.x) > cfg.bounds_half_width:
		motion.x = signf(next.x) * cfg.bounds_half_width - position.x
		lateral_vel.x = 0.0
	if absf(next.y) > cfg.bounds_half_height:
		motion.y = signf(next.y) * cfg.bounds_half_height - position.y
		lateral_vel.y = 0.0
	distance_travelled += forward_speed * delta
	if invulnerable:
		position += motion
	else:
		var col := move_and_collide(motion)
		if col:
			alive = false
			crashed.emit(col.get_collider())
			return false
	_update_visual(delta)
	return true


func _update_visual(delta: float) -> void:
	if visual == null:
		return
	# Target tilt: bank into the turn from lateral velocity, plus anticipation
	# from lateral acceleration; pitch with vertical motion; yaw into the turn.
	var accel := (lateral_vel - _prev_lat) / maxf(delta, 0.0001)
	_prev_lat = lateral_vel
	var vx := clampf(lateral_vel.x / cfg.max_lateral_speed, -1.3, 1.3)
	var ax := clampf(accel.x * cfg.tilt_anticipation / cfg.max_lateral_speed, -0.6, 0.6)
	var vy := clampf(lateral_vel.y / cfg.max_vertical_speed, -1.0, 1.0)
	var goal := Vector3(
		vy * deg_to_rad(cfg.pitch_max_deg),
		-vx * deg_to_rad(cfg.yaw_max_deg),
		-(vx + ax) * deg_to_rad(cfg.bank_max_deg))
	# damped spring (semi-implicit Euler) -> lively overshoot and settle
	var k := cfg.tilt_stiffness
	var c := 2.0 * sqrt(k) * cfg.tilt_damping
	_tilt_vel += ((goal - _tilt) * k - _tilt_vel * c) * delta
	_tilt += _tilt_vel * delta
	# barrel roll: one full revolution with an ease-in-out
	roll_angle = 0.0
	if rolling:
		var t := clampf(_roll_t / cfg.roll_duration, 0.0, 1.0)
		roll_angle = -roll_dir * TAU * (t * t * (3.0 - 2.0 * t))
	# idle hover: gentle bob and sway that fades out at speed
	_hover_t += delta
	var calm := clampf(1.0 - absf(vx) * 1.5, 0.0, 1.0) * (1.0 - cfg.speed_t(forward_speed) * 0.6)
	var bob := sin(_hover_t * 2.1) * cfg.hover_amplitude * calm
	var sway := sin(_hover_t * 1.3 + 0.7) * deg_to_rad(2.0) * calm
	visual.position = Vector3(0.0, bob, 0.0)
	visual.rotation = Vector3(_tilt.x + bob * 0.4, _tilt.y, _tilt.z + sway + roll_angle)
