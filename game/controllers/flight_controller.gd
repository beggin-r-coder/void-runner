class_name FlightController
extends CharacterBody3D
## Forward-auto, cross-section-constrained flight.
## Lateral / vertical velocity is acceleration limited toward a target point
## inside the bounded envelope. The visual mesh banks independently; there is
## no six-degree-of-freedom rigid body flight. move_and_collide sweeps the
## collision shape between the previous and new position each step, so thin
## obstacles cannot be tunnelled through at top speed.

signal crashed(collider: Object)

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
	if visual:
		visual.rotation = Vector3.ZERO
		visual.visible = true


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
	var pos2 := Vector2(position.x, position.y)
	var gain := follower.gain if follower != null else cfg.steer_response
	var desired := (target - pos2) * gain + _ff
	desired.x = clampf(desired.x, -cfg.max_lateral_speed, cfg.max_lateral_speed)
	desired.y = clampf(desired.y, -cfg.max_vertical_speed, cfg.max_vertical_speed)
	lateral_vel.x = move_toward(lateral_vel.x, desired.x, cfg.lateral_accel * delta)
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
	var k := 1.0 - exp(-10.0 * delta)
	var bank := -lateral_vel.x / cfg.max_lateral_speed * deg_to_rad(cfg.bank_max_deg)
	var pitch := lateral_vel.y / cfg.max_vertical_speed * deg_to_rad(cfg.pitch_max_deg)
	var yaw := -lateral_vel.x / cfg.max_lateral_speed * deg_to_rad(5.0)
	visual.rotation = visual.rotation.lerp(Vector3(pitch, yaw, bank), k)
