class_name TiltInput
extends Node
## DashCore: device tilt steering.
## Reads the fused gravity vector (gyro + accelerometer on Android; falls back
## to the raw accelerometer), low-pass filters it, and reports tilt RELATIVE to
## a calibrated reference, so it works however the player holds the phone
## (upright, reclined or flat). Godot rotates sensor axes to the current screen
## orientation, so screen-x is always "right" - including reverse landscape.
##
## read() returns -1..1 per axis: x = roll (right edge down = +),
## y = pitch (top edge tilted away = -). Dead zone and sensitivity applied.

var enabled: bool = false
## 0..1: 0 needs ~34 deg of tilt for full deflection, 1 needs ~12 deg.
var sensitivity: float = 0.5
var dead_zone_deg: float = 2.0
var filter_rate: float = 14.0
## Non-zero: used instead of the real sensor (tests, desktop dev).
var override_gravity: Vector3 = Vector3.ZERO

var _g: Vector3 = Vector3.ZERO
var _ref: Vector3 = Vector3(0, -1, 0)
var calibrated: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func max_angle_deg() -> float:
	return lerpf(34.0, 12.0, clampf(sensitivity, 0.0, 1.0))


func raw_gravity() -> Vector3:
	if override_gravity != Vector3.ZERO:
		return override_gravity
	var g := Input.get_gravity()
	if g.length_squared() < 0.01:
		g = Input.get_accelerometer()
	return g


## True when a motion sensor is actually delivering data.
func available() -> bool:
	return raw_gravity().length_squared() > 1.0


func _physics_process(delta: float) -> void:
	var g := raw_gravity()
	if g.length_squared() < 1.0:
		return
	g = g.normalized()
	if _g == Vector3.ZERO:
		_g = g
	else:
		_g = _g.lerp(g, 1.0 - exp(-filter_rate * delta)).normalized()


## Makes the current holding angle the neutral position.
func calibrate() -> void:
	var g := raw_gravity()
	if g.length_squared() < 1.0:
		return
	_ref = g.normalized()
	_g = _ref
	calibrated = true


## Tilt angles (radians) of g relative to ref: x = roll about the axis toward
## the player, y = pitch. Uses a basis built from ref, so the result does not
## depend on how steeply the phone is held.
static func tilt_angles(ref: Vector3, g: Vector3) -> Vector2:
	var ex := Vector3.RIGHT - ref * Vector3.RIGHT.dot(ref)
	if ex.length() < 0.2:  # phone held on its side relative to gravity
		ex = Vector3.UP.cross(ref)
	ex = ex.normalized()
	var ey := ref.cross(ex).normalized()
	return Vector2(asin(clampf(g.dot(ex), -1.0, 1.0)), asin(clampf(g.dot(ey), -1.0, 1.0)))


## Gravity in device coordinates for a phone held reclined by pitch_deg (top
## edge tilted away from the player) and rolled by roll_deg (right edge down).
## Used by tests and the dev harness to simulate a real sensor.
static func simulated_gravity(pitch_deg: float, roll_deg: float) -> Vector3:
	var d := Basis(Vector3(0, 0, 1), -deg_to_rad(roll_deg)) * Basis(Vector3(1, 0, 0), -deg_to_rad(pitch_deg))
	return d.inverse() * Vector3(0.0, -9.81, 0.0)


func read() -> Vector2:
	if _g == Vector3.ZERO:
		return Vector2.ZERO
	var a := tilt_angles(_ref, _g)
	var dz := deg_to_rad(dead_zone_deg)
	var mx := deg_to_rad(max_angle_deg())
	var out := Vector2.ZERO
	for i in 2:
		var v: float = a[i]
		out[i] = clampf(signf(v) * maxf(absf(v) - dz, 0.0) / maxf(mx - dz, 0.001), -1.0, 1.0)
	return out
