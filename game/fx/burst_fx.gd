class_name BurstFX
extends Node3D
## One-shot effects: near-miss sparks and the crash explosion + shockwave.

var mats: GameMaterials
var _near: GPUParticles3D
var _boom: GPUParticles3D
var _debris: GPUParticles3D
var _shock: MeshInstance3D
var _shock_mat: ShaderMaterial
var _shock_t: float = 1.0
var _flash_light: OmniLight3D


func setup(p_mats: GameMaterials) -> void:
	mats = p_mats
	_near = _particles(48, 0.45, 6.0, 22.0, Color(0.6, 1.0, 1.0), 0.05, 4.0)
	_boom = _particles(120, 1.2, 4.0, 26.0, Color(1.0, 0.55, 0.2), 0.16, 5.0)
	(_boom.process_material as ParticleProcessMaterial).damping_min = 8.0
	(_boom.process_material as ParticleProcessMaterial).damping_max = 14.0
	_debris = _particles(40, 1.6, 8.0, 30.0, Color(0.9, 0.9, 1.0), 0.08, 3.0)
	(_debris.process_material as ParticleProcessMaterial).gravity = Vector3(0, -6, 0)
	_shock = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	_shock.mesh = s
	_shock_mat = mats.shock(Color(1.0, 0.6, 0.3))
	_shock_mat.set_shader_parameter("energy", 1.6)
	_shock.material_override = _shock_mat
	_shock.visible = false
	add_child(_shock)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.6, 0.3)
	_flash_light.omni_range = 30.0
	_flash_light.light_energy = 0.0
	add_child(_flash_light)


func _particles(amount: int, life: float, vmin: float, vmax: float, col: Color, size: float, energy: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 180.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.4
	pm.scale_max = 1.4
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pm.scale_curve = curve
	p.process_material = pm
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	p.draw_pass_1 = m
	p.material_override = mats.energy(col, energy)
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	add_child(p)
	return p


func near_miss(pos: Vector3, color: Color) -> void:
	_near.global_position = pos
	(_near.material_override as ShaderMaterial).set_shader_parameter("color", color)
	_near.restart()


func explode(pos: Vector3, color: Color) -> void:
	for p in [_boom, _debris]:
		(p as GPUParticles3D).global_position = pos
		(p as GPUParticles3D).restart()
	(_debris.material_override as ShaderMaterial).set_shader_parameter("color", color)
	_shock.global_position = pos
	_shock.visible = true
	_shock_t = 0.0
	_flash_light.global_position = pos + Vector3(0, 1, 2)
	_flash_light.light_energy = 12.0


func shift(dz: float) -> void:
	for c in get_children():
		if c is Node3D:
			(c as Node3D).position.z += dz


func _process(delta: float) -> void:
	if _shock_t < 1.0:
		_shock_t = minf(_shock_t + delta * 2.2, 1.0)
		var r := 1.0 + 9.0 * ease(_shock_t, 0.35)
		_shock.scale = Vector3.ONE * r
		_shock_mat.set_shader_parameter("fade", 1.0 - _shock_t)
		if _shock_t >= 1.0:
			_shock.visible = false
	_flash_light.light_energy = move_toward(_flash_light.light_energy, 0.0, delta * 20.0)
