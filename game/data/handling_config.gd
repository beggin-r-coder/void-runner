class_name HandlingConfig
extends Resource
## All flight-feel tuning in one typed resource (res://game/data/handling_default.tres).
## Log every change in docs/TUNING_LOG.md.

@export_group("Flight envelope")
@export var bounds_half_width: float = 8.0
@export var bounds_half_height: float = 4.5
@export var ship_radius: float = 0.85
@export var safety_margin: float = 0.7

@export_group("Steering")
## World meters moved per full-screen-height drag.
@export var drag_gain: float = 26.0
@export var keyboard_speed: float = 16.0
@export var steer_response: float = 14.0
@export var max_lateral_speed: float = 28.0
@export var max_vertical_speed: float = 20.0
@export var lateral_accel: float = 150.0
@export var vertical_accel: float = 120.0
@export var invert_y: bool = false

@export_group("Smoothing")
## Smooth (jerk-limited, eased-arrival) player steering. false = legacy response.
@export var smooth_steering: bool = true
## Adaptive input filter: slow rate for tiny jitter, fast rate for big moves (1/s).
@export var input_smooth_min: float = 16.0
@export var input_smooth_max: float = 48.0
## Distance (m) at which the filter reaches its fast rate.
@export var input_smooth_span: float = 1.5
## Fraction of lateral acceleration used for the eased braking curve.
@export var brake_factor: float = 0.55
## Max rate of change of acceleration (m/s^3): removes snap starts and stops.
@export var steer_jerk: float = 2400.0

@export_group("Speed")
@export var base_speed: float = 35.0
@export var max_speed: float = 65.0
@export var speed_ramp_distance: float = 5000.0
@export var countdown_speed: float = 28.0
@export var attract_speed: float = 32.0

@export_group("Barrel roll")
## A full 360 deg roll that also sidesteps; never reduces what the validator
## assumes the ship can do, so it can only make layouts easier.
@export var roll_duration: float = 0.5
@export var roll_shift: float = 4.5
@export var roll_cooldown: float = 0.9
@export var roll_speed_mult: float = 1.7
@export var roll_accel_mult: float = 2.2

@export_group("Presentation")
@export var bank_max_deg: float = 52.0
@export var pitch_max_deg: float = 16.0
@export var yaw_max_deg: float = 9.0
## Spring that drives the visual tilt: lower damping = livelier overshoot.
@export var tilt_stiffness: float = 120.0
@export var tilt_damping: float = 0.74
## Extra tilt from lateral acceleration (anticipation), in seconds.
@export var tilt_anticipation: float = 0.06
@export var hover_amplitude: float = 0.07
@export var fov_base: float = 72.0
@export var fov_boost: float = 16.0
@export var reduced_motion_fov_boost: float = 5.0

@export_group("Scoring")
@export var near_miss_distance: float = 1.7
@export var near_miss_points: int = 40
@export var combo_max: int = 5
@export var combo_timeout: float = 4.0
@export var credits_per_score: int = 50

@export_group("Generation")
## Fraction of max lateral speed assumed reachable by the fairness validator.
@export var reach_efficiency: float = 0.55
@export var preview_seconds: float = 2.0


func speed_t(speed: float) -> float:
	return clampf((speed - base_speed) / maxf(max_speed - base_speed, 0.001), 0.0, 1.0)
