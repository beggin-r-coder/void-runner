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
var _smoothed_v: Vector2 = Vector2.ZERO
var _lead: float = 0.0
var _fov_v: float = 0.0
var _shake_t: float = 0.0
var _noise := FastNoiseLite.new()
## 0 = chase view, 1 = hangar showcase framing (ship to the left of the panel)
var framing_target: float = 0.0
var _framing: float = 0.0


func setup(p_ship: FlightController, p_cfg: HandlingConfig) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	ship = p_ship
	cfg = p_cfg
	fov = cfg.fov_base
	near = 0.1
	far = 900.0
	snap()


func snap() -> void:
	_smoothed = Vector2(ship.position.x, ship.position.y)
	_smoothed_v = Vector2.ZERO
	_lead = 0.0
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
	# critically damped spring follow: no stepping, no overshoot
	var w := 7.5
	var to := Vector2(sp.x, sp.y) - _smoothed
	_smoothed_v += (to * w * w - _smoothed_v * 2.0 * w) * delta
	_smoothed += _smoothed_v * delta
	# lean the view slightly into the turn so motion reads ahead of the ship
	_lead = lerpf(_lead, ship.lateral_vel.x / cfg.max_lateral_speed, 1.0 - exp(-4.0 * delta))
	_framing = move_toward(_framing, framing_target, delta * 1.8)
	var f := _framing * _framing * (3.0 - 2.0 * _framing)
	var pos := Vector3(_smoothed.x * 0.82, _smoothed.y * 0.7 + offset.y, sp.z + offset.z - speed_t * 0.8)
	pos = pos.lerp(sp + Vector3(2.6, 0.9, 4.6), f)
	global_position = pos
	var look := Vector3(sp.x * 0.9 + _lead * (0.0 if reduced_motion else 2.2), sp.y * 0.8 + 0.4, sp.z - look_ahead)
	look = look.lerp(sp + Vector3(2.2, 0.2, -1.5), f)
	look_at(look, Vector3.UP)
	var roll_target := 0.0 if reduced_motion else -ship.lateral_vel.x / cfg.max_lateral_speed * deg_to_rad(9.0)
	_roll = lerpf(_roll, roll_target, k)
	rotate_object_local(Vector3.FORWARD, -_roll)
	var boost := cfg.reduced_motion_fov_boost if reduced_motion else cfg.fov_boost
	var target_fov := cfg.fov_base + boost * speed_t + _kick
	# springy FOV (slightly underdamped) so kicks swell and settle
	_fov_v += ((target_fov - fov) * 40.0 - _fov_v * 2.0 * sqrt(40.0) * 0.8) * delta
	fov += _fov_v * delta
	_kick = move_toward(_kick, 0.0, delta * 30.0)
	if _shake > 0.0:
		# smooth noise rumble instead of per-frame random jumps
		_shake_t += delta * 22.0
		h_offset = _noise.get_noise_2d(_shake_t, 0.0) * _shake * 0.45
		v_offset = _noise.get_noise_2d(0.0, _shake_t + 50.0) * _shake * 0.45
		_shake = move_toward(_shake, 0.0, delta * 2.5)
	else:
		h_offset = 0.0
		v_offset = 0.0
