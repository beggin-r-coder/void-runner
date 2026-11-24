class_name ChaseCamera
extends Camera3D
## Chase camera: follows position with modest bank and a capped FOV increase.
## Reduced motion removes roll and shake and limits FOV change.

var ship: FlightController
var cfg: HandlingConfig
var reduced_motion: bool = false
var offset: Vector3 = Vector3(0.0, 2.3, 7.2)
var look_ahead: float = 26.0
var _shake: float = 0.0
var _kick: float = 0.0
var _roll: float = 0.0
var _smoothed: Vector2 = Vector2.ZERO


func setup(p_ship: FlightController, p_cfg: HandlingConfig) -> void:
	ship = p_ship
	cfg = p_cfg
	fov = cfg.fov_base
	near = 0.1
	far = 1400.0
	snap()


func snap() -> void:
	_smoothed = Vector2(ship.position.x, ship.position.y)
	global_position = ship.global_position + offset
	_shake = 0.0
	_kick = 0.0


func add_shake(amount: float) -> void:
	if not reduced_motion:
		_shake = maxf(_shake, amount)


func add_kick(fov_kick: float) -> void:
	if not reduced_motion:
		_kick = maxf(_kick, fov_kick)


func update_camera(delta: float, speed_t: float) -> void:
	var sp := ship.global_position
	var k := 1.0 - exp(-7.0 * delta)
	_smoothed = _smoothed.lerp(Vector2(sp.x, sp.y), k)
	var pos := Vector3(_smoothed.x * 0.82, _smoothed.y * 0.7 + offset.y, sp.z + offset.z - speed_t * 0.8)
	global_position = pos
	var look := Vector3(sp.x * 0.9, sp.y * 0.8 + 0.4, sp.z - look_ahead)
	look_at(look, Vector3.UP)
	var roll_target := 0.0 if reduced_motion else -ship.lateral_vel.x / cfg.max_lateral_speed * deg_to_rad(9.0)
	_roll = lerpf(_roll, roll_target, k)
	rotate_object_local(Vector3.FORWARD, -_roll)
	var boost := cfg.reduced_motion_fov_boost if reduced_motion else cfg.fov_boost
	var target_fov := cfg.fov_base + boost * speed_t + _kick
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))
	_kick = move_toward(_kick, 0.0, delta * 30.0)
	if _shake > 0.0:
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.25
		_shake = move_toward(_shake, 0.0, delta * 2.5)
	else:
		h_offset = 0.0
		v_offset = 0.0
