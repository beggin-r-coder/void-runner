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
var _mm_stem: MultiMeshInstance3D
var _mm_glow_b: MultiMeshInstance3D


func build() -> void:
	match kind:
		0, 3, 4:
			_a = _mi()
			_b = _mi()
			_floor = _mi()
			_ring = _mi(meshes["ring"])
			_mm_main = _mmi(meshes["spire"], 6 if kind != 4 else 5)
			_mm_glow = _mmi(meshes["shard"], 18 if kind != 4 else 26)
		5:
			_floor = _mi()
			_ring = _mi(meshes["ring"])
			_mm_main = _mmi(meshes["spire"], 22)
			_mm_glow = _mmi(meshes["shard"], 22)
			var asts: Array = meshes["asteroids"]
			_mm_alt = _mmi(asts[2], 7)
			_mm_stem = _mmi(meshes["cyl"], 7)
			_mm_glow_b = _mmi(meshes["shard"], 14)
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


## Every instance transform set this layout, per MultiMesh (the headless
## dummy renderer does not store them; tests read this instead).
var instance_xforms: Dictionary = {}


func _put(mm: MultiMesh, i: int, t: Transform3D) -> void:
	mm.set_instance_transform(i, t)
	var arr: Array = instance_xforms.get(mm, [])
	if arr.size() < mm.instance_count:
		arr.resize(mm.instance_count)
	arr[i] = t
	instance_xforms[mm] = arr


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
		3:
			_canyon(rng, length, tm)
			_ice_extras(rng, length)
		4:
			_canyon(rng, length, tm)
			_volcanic_extras(rng, length)
		5:
			_reef(rng, length, tm)
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
		_put(mm, i, t)
	var mg := _mm_glow.multimesh
	_mm_glow.material_override = tm["crystal"]
	for i in mg.instance_count:
		var side2 := -1.0 if i % 2 == 0 else 1.0
		var s := rng.randf_range(0.5, 1.6)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, -side2 * rng.randf_range(0.2, 0.7))).scaled(Vector3(s, s * rng.randf_range(1.2, 2.4), s))
		_put(mg, i, Transform3D(b, Vector3(side2 * rng.randf_range(10.5, 14.0), rng.randf_range(-7.8, -6.8), -rng.randf_range(0.0, length))))


## Ice moon: tall jagged ice spires on the skyline, big upright crystal clusters.
func _ice_extras(rng: RandomNumberGenerator, length: float) -> void:
	var mm := _mm_main.multimesh
	for i in mm.instance_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := rng.randf_range(40.0, 95.0)
		var w := rng.randf_range(2.5, 6.0)
		var b := Basis.from_euler(Vector3(0, rng.randf() * TAU, side * rng.randf_range(0.0, 0.15))).scaled(Vector3(w, h, w))
		_put(mm, i, Transform3D(b, Vector3(side * rng.randf_range(30.0, 100.0), -10.0 + h * 0.85, -rng.randf_range(0.0, length))))
	var mg := _mm_glow.multimesh
	for i in mg.instance_count:
		var side2 := -1.0 if i % 2 == 0 else 1.0
		var s := rng.randf_range(0.9, 2.6)
		var b2 := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, -side2 * rng.randf_range(0.1, 0.45))).scaled(Vector3(s, s * rng.randf_range(2.0, 3.5), s))
		_put(mg, i, Transform3D(b2, Vector3(side2 * rng.randf_range(11.5, 16.0), rng.randf_range(-7.5, -6.5), -rng.randf_range(0.0, length))))


## Volcanic world: broad volcano cones on the skyline, glowing lava rocks
## scattered along the canyon floor edges.
func _volcanic_extras(rng: RandomNumberGenerator, length: float) -> void:
	var mm := _mm_main.multimesh
	for i in mm.instance_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := rng.randf_range(22.0, 45.0)
		var w := rng.randf_range(14.0, 26.0)
		_put(mm, i, Transform3D(Basis.from_scale(Vector3(w, h, w)), Vector3(side * rng.randf_range(55.0, 130.0), -10.0 + h * 0.75, -rng.randf_range(0.0, length))))
	var mg := _mm_glow.multimesh
	for i in mg.instance_count:
		var side2 := -1.0 if i % 2 == 0 else 1.0
		var s := rng.randf_range(0.4, 1.1)
		var b2 := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(s, s * 0.7, s))
		_put(mg, i, Transform3D(b2, Vector3(side2 * rng.randf_range(9.5, 15.0), rng.randf_range(-7.9, -7.2), -rng.randf_range(0.0, length))))


## Bioluminescent reef: coral stalks with glowing tips, giant mushrooms,
## glowing moss floor and an occasional tentacle arch over the corridor.
func _reef(rng: RandomNumberGenerator, length: float, tm: Dictionary) -> void:
	var fl: Array = meshes["floors"]
	_floor.mesh = fl[rng.randi_range(0, fl.size() - 1)]
	_floor.material_override = tm["deco_floor"]
	_ring.visible = rng.randf() < 0.35
	_ring.material_override = tm["deco_rock"]
	_ring.position = Vector3(rng.randf_range(-2.0, 2.0), -10.0, -rng.randf_range(20.0, length - 20.0))
	# tentacle arch: round (a squashed arch dips into the flight space), slight yaw only
	# inner radius must clear the envelope corner: sqrt(8.85^2 + 15.35^2) = 17.7 m
	_ring.rotation = Vector3(PI * 0.5, rng.randf_range(-0.2, 0.2), 0.0)
	_ring.scale = Vector3.ONE * rng.randf_range(22.5, 26.0)
	var mm := _mm_main.multimesh
	var mg := _mm_glow.multimesh
	_mm_main.material_override = tm["deco_rock"]
	_mm_glow.material_override = tm["crystal"]
	for i in mm.instance_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var near := i < 10
		var h := rng.randf_range(8.0, 20.0) if near else rng.randf_range(20.0, 55.0)
		var w := rng.randf_range(0.8, 1.8) if near else rng.randf_range(2.0, 5.0)
		var x := side * (rng.randf_range(11.0, 17.0) if near else rng.randf_range(20.0, 80.0))
		var lean := -side * rng.randf_range(0.05, 0.3)  # lean away from the corridor
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, lean)).scaled(Vector3(w, h, w))
		var base := Vector3(x, -9.0 + h, -rng.randf_range(0.0, length))
		_put(mm, i, Transform3D(b, base))
		# glowing bulb at the stalk tip
		var tip := base + b.y * 1.0
		var ts := w * rng.randf_range(0.9, 1.6)
		_put(mg, i, Transform3D(Basis.from_euler(Vector3(PI, 0, 0)).scaled(Vector3(ts, ts * 1.4, ts)), tip))
	var caps := _mm_alt.multimesh
	var stems := _mm_stem.multimesh
	_mm_alt.material_override = tm["deco_rock"]
	_mm_stem.material_override = tm["deco_rock"]
	for i in caps.instance_count:
		var side3 := -1.0 if i % 2 == 0 else 1.0
		var r := rng.randf_range(7.0, 16.0)
		var hh := rng.randf_range(10.0, 26.0)
		var p := Vector3(side3 * rng.randf_range(22.0 + r, 70.0), -9.0, -rng.randf_range(0.0, length))
		_put(stems, i, Transform3D(Basis.from_scale(Vector3(r * 0.14, hh * 0.5, r * 0.14)), p + Vector3(0, hh * 0.5, 0)))
		_put(caps, i, Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(r, r * 0.32, r)), p + Vector3(0, hh, 0)))
	var gb := _mm_glow_b.multimesh
	_mm_glow_b.material_override = tm.get("crystal_b", tm["crystal"])
	for i in gb.instance_count:
		var side4 := -1.0 if i % 2 == 0 else 1.0
		var s4 := rng.randf_range(0.3, 0.8)
		_put(gb, i, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))).scaled(Vector3(s4, s4 * 2.0, s4)), Vector3(side4 * rng.randf_range(9.5, 18.0), rng.randf_range(-7.8, -6.8), -rng.randf_range(0.0, length))))


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
			_put(mm, i, Transform3D(b, p))
	var mg := _mm_glow.multimesh
	_mm_glow.material_override = tm["crystal"]
	for i in mg.instance_count:
		var ang2 := rng.randf() * TAU
		var r2 := rng.randf_range(16.0, 60.0)
		var s2 := rng.randf_range(0.8, 2.5)
		var b2 := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(s2, s2 * 2.5, s2))
		_put(mg, i, Transform3D(b2, Vector3(cos(ang2) * r2, sin(ang2) * r2 * 0.7, -rng.randf_range(0.0, length))))
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
		_put(mm, i, Transform3D(b, Vector3(x, -10.0 + h, -rng.randf_range(0.0, length))))
	_bridge.visible = rng.randf() < 0.45
	_bridge.material_override = tm["deco_ruin"]
	_bridge.position = Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(12.0, 18.0), -rng.randf_range(15.0, length - 15.0))
	_bridge.scale = Vector3(rng.randf_range(25.0, 45.0), rng.randf_range(0.8, 1.6), rng.randf_range(2.0, 4.0))
	_bridge.rotation = Vector3(0, 0, rng.randf_range(-0.12, 0.12))
	_ring.visible = rng.randf() < 0.4
	_ring.material_override = tm["deco_ruin"]
	_ring.position = Vector3(0, rng.randf_range(-1.0, 1.0), -rng.randf_range(20.0, length - 20.0))
	# stand the gate upright facing the corridor (a pre-roll would tilt it into the flight space)
	_ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_ring.scale = Vector3.ONE * rng.randf_range(16.5, 19.0)
	var mg := _mm_glow.multimesh
	_mm_glow.material_override = tm["crystal"]
	for i in mg.instance_count:
		var side2 := -1.0 if i % 2 == 0 else 1.0
		var b2 := Basis.from_scale(Vector3(0.12, 0.06, length * 0.5))
		_put(mg, i, Transform3D(b2, Vector3(side2 * (10.5 + (i / 2) * 3.5), -8.45, -length * 0.5)))
