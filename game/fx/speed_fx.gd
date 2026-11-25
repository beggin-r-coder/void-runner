class_name SpeedFX
extends Node3D
## Speed presentation layer: listens to speed, never affects collision.
## Speed streaks around the camera, engine plume throttle, engine sparks,
## ribbon trails and the post-process intensity.

var cam: Camera3D
var streaks: GPUParticles3D
var dust: GPUParticles3D
var sparks: Array[GPUParticles3D] = []
var trails: Array[Trail3D] = []
var flames: Array[MeshInstance3D] = []
var quality_high: bool = true
# fluid plume state: spring-smoothed length / throttle, lagging tail bend, surges
var _flame_len: PackedFloat32Array = PackedFloat32Array([1.0, 1.0])
var _flame_len_v: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _throttle: float = 0.8
var _bend: Vector2 = Vector2.ZERO
var _bend_v: Vector2 = Vector2.ZERO
var _surge: float = 0.0
# ship detail animation
var petals: Array = []
var turbines: Array = []
var heat_rings: Array = []
var strobes: Array = []
var rcs: Dictionary = {}
var _rcs_level: Vector2 = Vector2.ZERO  # x = left jet, y = right jet
var _prev_lat_vel: Vector2 = Vector2.ZERO
var _anim_t: float = 0.0


## Momentary thrust surge (roll, near miss, launch): longer, brighter plume.
func surge(amount: float) -> void:
	_surge = maxf(_surge, amount)
var _streak_mat: ShaderMaterial


func setup(p_cam: Camera3D, mats: GameMaterials) -> void:
	cam = p_cam
	_streak_mat = mats.trail(Color(1, 0.9, 0.8), 2.2)
	_streak_mat.set_shader_parameter("head_fade", 0.3)
	streaks = _make_streaks(MeshFactory.streak(5.0, 0.035), _streak_mat, 140, 14.0, 4.5)
	cam.add_child(streaks)
	var dust_mat := mats.energy(Color(0.8, 0.85, 1.0), 1.2)
	var dmesh := SphereMesh.new()
	dmesh.radius = 0.03
	dmesh.height = 0.06
	dmesh.radial_segments = 4
	dmesh.rings = 2
	dust = _make_streaks(dmesh, dust_mat, 90, 9.0, 1.5)
	cam.add_child(dust)


func _make_streaks(mesh: Mesh, mat: Material, amount: int, radius: float, inner: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.7
	p.preprocess = 0.7
	p.local_coords = true
	p.position = Vector3(0, 0, -70)
	p.visibility_aabb = AABB(Vector3(-30, -30, -90), Vector3(60, 60, 180))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = inner
	pm.emission_ring_height = 30.0
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 0.0
	pm.initial_velocity_min = 110.0
	pm.initial_velocity_max = 150.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func attach_ship(ship_parts: Dictionary, mats: GameMaterials, world: Node3D) -> void:
	for t in trails:
		t.queue_free()
	trails.clear()
	for s in sparks:
		s.queue_free()
	sparks.clear()
	flames = ship_parts["flames"]
	petals = ship_parts.get("petals", [])
	turbines = ship_parts.get("turbines", [])
	heat_rings = ship_parts.get("heat_rings", [])
	strobes = ship_parts.get("strobes", [])
	rcs = ship_parts.get("rcs", {})
	var accent: Color = ship_parts["accent"]
	var flame_col: Color = ship_parts["flame_color"]
	for tip in ship_parts["wingtips"]:
		var tr := Trail3D.new()
		tr.emitter = tip
		tr.camera = cam
		tr.width = 0.07
		tr.max_points = 16
		tr.material_override = mats.trail(accent, 2.5)
		world.add_child(tr)
		trails.append(tr)
	for nz in ship_parts["nozzles"]:
		var tr2 := Trail3D.new()
		tr2.emitter = nz
		tr2.camera = cam
		# thin heat wisp only: the fluid plume mesh is the visible thrust
		tr2.width = 0.07
		tr2.max_points = 9
		tr2.material_override = mats.trail(flame_col, 0.7)
		world.add_child(tr2)
		trails.append(tr2)
		var sp := GPUParticles3D.new()
		sp.amount = 40
		sp.lifetime = 0.35
		sp.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 0, 1)
		pm.spread = 12.0
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 10.0
		pm.gravity = Vector3.ZERO
		pm.scale_min = 0.5
		pm.scale_max = 1.0
		pm.color = flame_col
		sp.process_material = pm
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		sm.radial_segments = 4
		sm.rings = 2
		sp.draw_pass_1 = sm
		sp.material_override = mats.energy(flame_col.lightened(0.4), 5.0)
		sp.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 80))
		(nz as Node3D).add_child(sp)
		sparks.append(sp)


func _animate_ship(delta: float, speed_t: float, flying: bool, lat_vel: Vector2) -> void:
	_anim_t += delta
	var th := _throttle
	# petal nozzles iris open with throttle and surges
	var open := deg_to_rad(3.0 + 13.0 * clampf(th - 0.4, 0.0, 1.2))
	for h in petals:
		(h as Node3D).rotation.x = lerpf((h as Node3D).rotation.x, -open, 1.0 - exp(-8.0 * delta))
	for t in turbines:
		(t as Node3D).rotation.z += delta * (6.0 + 34.0 * th)
	for r in heat_rings:
		var m := (r as MeshInstance3D).material_override as ShaderMaterial
		m.set_shader_parameter("energy", 0.8 + 1.4 * speed_t + 6.0 * _surge)
		(r as Node3D).scale = Vector3.ONE * (1.0 + 0.25 * _surge)
	# RCS: accelerating right fires the left wingtip jet (pushing), and vice versa
	var acc := (lat_vel - _prev_lat_vel) / maxf(delta, 0.0001)
	_prev_lat_vel = lat_vel
	var goal := Vector2(clampf(acc.x / 110.0, 0.0, 1.0), clampf(-acc.x / 110.0, 0.0, 1.0)) if flying else Vector2.ZERO
	_rcs_level = _rcs_level.lerp(goal, 1.0 - exp(-(22.0 if goal.length() > _rcs_level.length() else 9.0) * delta))
	for side in ["left", "right"]:
		if not rcs.has(side):
			continue
		var jet: MeshInstance3D = rcs[side]
		var lvl := _rcs_level.x if side == "left" else _rcs_level.y
		jet.visible = lvl > 0.04
		jet.scale = Vector3(0.05, 0.05, 0.08 + 0.75 * lvl)
		(jet.material_override as ShaderMaterial).set_shader_parameter("throttle", 0.4 + 1.2 * lvl)
	# anti-collision strobe: double flash every 1.4 s
	var ph := fmod(_anim_t, 1.4)
	for st in strobes:
		(st as Node3D).visible = ph < 0.05 or (ph > 0.14 and ph < 0.19)


func set_theme_color(c: Color) -> void:
	_streak_mat.set_shader_parameter("color", c)


func sample_trails() -> void:
	for t in trails:
		t.sample()


func clear_trails() -> void:
	for t in trails:
		t.clear()


func shift(dz: float) -> void:
	for t in trails:
		t.shift(dz)


func set_ship_visible(v: bool) -> void:
	for t in trails:
		t.visible = v
	for s in sparks:
		s.emitting = v


## lateral: -1..1 normalized sideways velocity; bank: |visual roll| in radians.
## lat_vel: ship lateral velocity (m/s); roll_z: visual roll (rad) to map it into ship space.
func update_fx(speed_t: float, flying: bool, delta: float, lateral: float = 0.0, bank: float = 0.0, lat_vel: Vector2 = Vector2.ZERO, roll_z: float = 0.0) -> void:
	var ratio := (0.15 + 0.85 * speed_t) if flying else 0.0
	if not quality_high:
		ratio *= 0.5
	streaks.amount_ratio = ratio
	streaks.emitting = ratio > 0.01
	dust.amount_ratio = 0.5 + 0.5 * speed_t if flying else 0.3
	var pm := streaks.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = 90.0 + 80.0 * speed_t
	pm.initial_velocity_max = 130.0 + 100.0 * speed_t
	_streak_mat.set_shader_parameter("energy", 1.2 + 2.0 * speed_t)
	_surge = move_toward(_surge, 0.0, delta * 1.6)
	# tail lags behind lateral motion: spring toward the opposite of velocity,
	# expressed in the (banked / rolling) ship frame
	var goal_bend := (-lat_vel * 0.032).rotated(-roll_z)
	_bend_v += ((goal_bend - _bend) * 55.0 - _bend_v * 2.0 * sqrt(55.0) * 0.45) * delta
	_bend += _bend_v * delta
	_throttle = lerpf(_throttle, (0.75 + 0.4 * speed_t + _surge) if flying else 0.0, 1.0 - exp(-6.0 * delta))
	for i in flames.size():
		var f := flames[i]
		var side := -1.0 if i == 0 else 1.0
		# differential thrust: the outer engine flares when turning
		var flare := maxf(0.0, -side * lateral) * 0.9
		var goal := (2.3 + 2.4 * speed_t + flare * 1.4) * (1.0 + 0.6 * _surge)
		# critically-damped-ish spring: length eases instead of snapping
		_flame_len_v[i] += ((goal - _flame_len[i]) * 90.0 - _flame_len_v[i] * 2.0 * sqrt(90.0) * 0.8) * delta
		_flame_len[i] += _flame_len_v[i] * delta
		var w := 0.19 * (1.0 + flare * 0.2 + _surge * 0.15)
		f.scale = Vector3(w, w, maxf(_flame_len[i], 0.2))
		for m in [f.material_override, (f.get_child(0) as MeshInstance3D).material_override if f.get_child_count() > 0 else null]:
			if m:
				(m as ShaderMaterial).set_shader_parameter("bend", _bend)
				(m as ShaderMaterial).set_shader_parameter("throttle", _throttle * (1.0 + flare * 0.3))
	_animate_ship(delta, speed_t, flying, lat_vel)
	# wingtip vapour brightens in hard banks and rolls
	for i in mini(2, trails.size()):
		var m := trails[i].material_override as ShaderMaterial
		m.set_shader_parameter("energy", 2.0 + clampf(bank, 0.0, 1.6) * 3.5)
