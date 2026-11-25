class_name PerfGovernor
extends Node
## Keeps mobile frame times steady without visibly lowering quality:
## - 3D renders at ~720p internal height and is upscaled with FSR 1.0
##   (edge-aware upscale + sharpening). The 2D UI stays at native resolution.
## - Dynamic resolution: if frames run long the 3D scale steps down a little;
##   with headroom it climbs back to the target.
## - Frame cap: a steady 60 fps instead of judder between 60 and 120 Hz.
## Active on mobile, or anywhere with --mobile-sim (for testing).

var active: bool = false
var target_fps: int = 60
var high_quality: bool = true
var min_scale: float = 0.5
var base_scale: float = 1.0
var scale: float = 1.0
var _acc_ms: float = 0.0
var _frames: int = 0
var _calm_windows: int = 0
var _last_us: int = 0
var changes: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = OS.has_feature("mobile") or "--mobile-sim" in OS.get_cmdline_user_args()
	if active:
		Engine.max_fps = target_fps
	get_viewport().size_changed.connect(_recompute_base)


## Internal 3D height to aim for (UI is unaffected).
func target_height() -> float:
	return 760.0 if high_quality else 620.0


func configure(p_high_quality: bool) -> void:
	high_quality = p_high_quality
	_recompute_base()


func _recompute_base() -> void:
	var vp := get_viewport()
	if not active:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0 if high_quality else 0.75
		return
	var h := float(DisplayServer.window_get_size().y)
	if h <= 0.0:
		h = vp.get_visible_rect().size.y
	base_scale = clampf(target_height() / maxf(h, 1.0), min_scale, 1.0)
	scale = base_scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.fsr_sharpness = 0.25  # 0 = sharpest
	vp.scaling_3d_scale = scale


func _process(_delta: float) -> void:
	if not active or get_tree().paused:
		_last_us = 0
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_acc_ms += (now - _last_us) / 1000.0
		_frames += 1
	_last_us = now
	if _frames < 45:
		return
	var avg := _acc_ms / _frames
	_acc_ms = 0.0
	_frames = 0
	var budget := 1000.0 / target_fps
	if avg > budget * 1.12 and scale > min_scale:
		scale = maxf(min_scale, scale - 0.06)
		_calm_windows = 0
		_apply()
	elif avg < budget * 0.82 and scale < base_scale:
		_calm_windows += 1
		if _calm_windows >= 3:
			scale = minf(base_scale, scale + 0.04)
			_calm_windows = 0
			_apply()
	else:
		_calm_windows = 0


func _apply() -> void:
	changes += 1
	get_viewport().scaling_3d_scale = scale
