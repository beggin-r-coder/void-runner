class_name ChunkDressing
extends Node3D
## Non-collidable scenery for one chunk. Everything stays outside the flight
## envelope (|x| > 9.5 or |y| > 6.5) so decoration never reads as a hazard
## inside the corridor. Layout is re-randomized from the cosmetic stream.

var kind: int = 0
var meshes: Dictionary
var materials: GameMaterials

var _a: MeshInstance3D
var _b: MeshInstance3D
var _floor: MeshInstance3D
var _ring: MeshInstance3D
var _bridge: MeshInstance3D
var _mm_main: MultiMeshInstance3D
var _mm_alt: MultiMeshInstance3D
var _mm_glow: MultiMeshInstance3D
var _hero: MeshInstance3D


func build() -> void:
	match kind:
		0:
			_a = _mi()
			_b = _mi()
			_floor = _mi()
			_ring = _mi(meshes["ring"])
			_mm_main = _mmi(meshes["spire"], 6)
			_mm_glow = _mmi(meshes["shard"], 18)
		1:
			var asts: Array = meshes["asteroids"]
			_mm_main = _mmi(asts[0], 34)
			_mm_alt = _mmi(asts[3], 34)
			_mm_glow = _mmi(meshes["shard"], 10)
			_hero = _mi(asts[5])
		_:
			var floor_mesh := BoxMesh.new()
			floor_mesh.size = Vector3(2, 2, 2)
			_floor = _mi(floor_mesh)
			_mm_main = _mmi(floor_mesh, 14)
			_bridge = _mi(floor_mesh)
			_ring = _mi(meshes["ring"])
			_mm_glow = _mmi(floor_mesh, 4)


func _mi(mesh: Mesh = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	add_child(m)
	return m


func _mmi(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	return inst


func on_acquire() -> void:
	visible = true


func on_release() -> void:
	visible = false


func randomize_layout(rng: RandomNumberGenerator, length: float, tm: Dictionary) -> void:
	match kind:
		0:
			_canyon(rng, length, tm)
		1:
			_belt(rng, length, tm)
		_:
			_ruins(rng, length, tm)


func _canyon(rng: RandomNumberGenerator, length: float, tm: Dictionary) -> void:
	var wl: Array = meshes["walls_l"]
	var wr: Array = meshes["walls_r"]
	var fl: Array = meshes["floors"]
	_a.mesh = wl[rng.randi_range(0, wl.size() - 1)]
	_b.mesh = wr[rng.randi_range(0, wr.size() - 1)]
	_floor.mesh = fl[rng.randi_range(0, fl.size() - 1)]
	_a.position = Vector3(-rng.randf_range(0.0, 2.0), rng.randf_range(-1.0, 1.0), 0)
	_b.position = Vector3(rng.randf_range(0.0, 2.0), rng.randf_range(-1.0, 1.0), 0)
	_a.material_override = tm["deco_rock"]
	_b.material_override = tm["deco_rock"]
	_floor.material_override = tm["deco_floor"]
	_ring.visible = rng.randf() < 0.3
	_ring.material_override = tm["deco_rock"]
	_ring.position = Vector3(rng.randf_range(-2.0, 2.0), -9.0, -rng.randf_range(20.0, length - 20.0))
	_ring.rotation = Vector3(PI * 0.5, 0, rng.randf_range(-0.1, 0.1))
	_ring.scale = Vector3.ONE * rng.randf_range(21.0, 25.0)
	var mm := _mm_main.multimesh
	_mm_main.material_override = tm["deco_rock"]
	for i in mm.instance_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := rng.randf_range(25.0, 70.0)
		var w := rng.randf_range(3.0, 8.0)
		var t := Transform3D(Basis.from_scale(Vector3(w, h, w)), Vector3(side * rng.randf_range(38.0, 110.0), -10.0 + h * 0.8, -rng.randf_range(0.0, length)))
		mm.set_instance_transform(i, t)
	var mg := _mm_glow.multimesh
	_mm_glow.material_override = tm["crystal"]
	for i in mg.instance_count:
		var side2 := -1.0 if i % 2 == 0 else 1.0
		var s := rng.randf_range(0.5, 1.6)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, side2 * rng.randf_range(0.2, 0.7))).scaled(Vector3(s, s * rng.randf_range(1.2, 2.4), s))
		mg.set_instance_transform(i, Transform3D(b, Vector3(side2 * rng.randf_range(10.5, 14.0), rng.randf_range(-7.8, -6.8), -rng.randf_range(0.0, length))))


func _belt(rng: RandomNumberGenerator, length: float, tm: Dictionary) -> void:
	for inst in [_mm_main, _mm_alt]:
		var m: MultiMeshInstance3D = inst
		m.material_override = tm["deco_rock"]
		var mm := m.multimesh
		for i in mm.instance_count:
			var s := rng.randf_range(0.6, 2.0)
			if rng.randf() < 0.25:
				s = rng.randf_range(3.0, 9.0)
			var ang := rng.randf() * TAU
			var r := rng.randf_range(12.0 + s, 85.0)
			var p := Vector3(cos(ang) * r, sin(ang) * r * 0.7, -rng.randf_range(-5.0, length + 5.0))
			if absf(p.x) < 10.5 + s and absf(p.y) < 7.0 + s:
				p.x = sign(p.x + 0.001) * (10.5 + s + rng.randf_range(0.0, 6.0))
			var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * s)
			mm.set_instance_transform(i, Transform3D(b, p))
	var mg := _mm_glow.multimesh
	_mm_glow.material_override = tm["crystal"]
	for i in mg.instance_count:
		var ang2 := rng.randf() * TAU
		var r2 := rng.randf_range(16.0, 60.0)
		var s2 := rng.randf_range(0.8, 2.5)
		var b2 := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(s2, s2 * 2.5, s2))
		mg.set_instance_transform(i, Transform3D(b2, Vector3(cos(ang2) * r2, sin(ang2) * r2 * 0.7, -rng.randf_range(0.0, length))))
	_hero.visible = rng.randf() < 0.35
	_hero.material_override = tm["deco_rock"]
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	_hero.position = Vector3(side * rng.randf_range(90.0, 150.0), rng.randf_range(-40.0, 40.0), -rng.randf_range(0.0, length))
	_hero.scale = Vector3.ONE * rng.randf_range(25.0, 50.0)
	_hero.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)


func _ruins(rng: RandomNumberGenerator, length: float, tm: Dictionary) -> void:
	_floor.material_override = tm["deco_floor"]
	_floor.position = Vector3(0, -10.0, -length * 0.5)
	_floor.scale = Vector3(70.0, 1.5, length * 0.5 + 0.5)
	var mm := _mm_main.multimesh
	_mm_main.material_override = tm["deco_ruin"]
	for i in mm.instance_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := rng.randf_range(12.0, 55.0)
		if rng.randf() < 0.2:
			h = rng.randf_range(60.0, 110.0)
		var w := rng.randf_range(2.0, 6.0)
		var d := rng.randf_range(2.0, 6.0)
		var x := side * (rng.randf_range(15.0, 70.0) + w)
		var b := Basis.from_euler(Vector3(0, rng.randf_range(-0.2, 0.2), rng.randf_range(-0.06, 0.06))).scaled(Vector3(w, h, d))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, -10.0 + h, -rng.randf_range(0.0, length))))
	_bridge.visible = rng.randf() < 0.45
	_bridge.material_override = tm["deco_ruin"]
	_bridge.position = Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(12.0, 18.0), -rng.randf_range(15.0, length - 15.0))
	_bridge.scale = Vector3(rng.randf_range(25.0, 45.0), rng.randf_range(0.8, 1.6), rng.randf_range(2.0, 4.0))
	_bridge.rotation = Vector3(0, 0, rng.randf_range(-0.12, 0.12))
	_ring.visible = rng.randf() < 0.4
	_ring.material_override = tm["deco_ruin"]
	_ring.position = Vector3(0, rng.randf_range(-1.0, 1.0), -rng.randf_range(20.0, length - 20.0))
	_ring.rotation = Vector3(PI * 0.5, 0, rng.randf_range(0.0, TAU))
	_ring.scale = Vector3.ONE * rng.randf_range(16.5, 19.0)
	var mg := _mm_glow.multimesh
	_mm_glow.material_override = tm["crystal"]
	for i in mg.instance_count:
		var side2 := -1.0 if i % 2 == 0 else 1.0
		var b2 := Basis.from_scale(Vector3(0.12, 0.06, length * 0.5))
		mg.set_instance_transform(i, Transform3D(b2, Vector3(side2 * (10.5 + (i / 2) * 3.5), -8.45, -length * 0.5)))
