class_name WorldDresser
extends Node3D
## Spawns the visual + physical representation of ChunkPlans from pools.
## Cosmetic choices use the cosmetic RNG stream only.

var materials: GameMaterials
var profiles: Array
var pool: NodePool
var _storage: Node3D
var _meshes: Dictionary = {}
const PREWARM := [64, 96, 40, 12]


func setup(p_profiles: Array, p_materials: GameMaterials) -> void:
	profiles = p_profiles
	materials = p_materials
	_storage = Node3D.new()
	_storage.name = "PoolStorage"
	add_child(_storage)
	pool = NodePool.new(_storage)
	_build_meshes()
	# Prewarmed to the peak concurrent demand measured in the 50-run soak
	# (docs/DEVICE_BENCHMARKS.md) so gameplay never allocates mid-run.
	for k in 4:
		var kind := k
		pool.register(StringName("obs_%d" % k), func() -> Node: return ObstacleNode.new(kind), PREWARM[k])
	pool.register(&"orbs", _make_orbs, 8)
	for kind in 6:
		var dk := kind
		pool.register(StringName("dress_%d" % kind), func() -> Node: return _make_dressing(dk), 9)


func _build_meshes() -> void:
	_meshes["box"] = MeshFactory.rounded_box(10, 0.16)
	_meshes["cyl"] = MeshFactory.smooth_cylinder(18, 12, true)
	var asts: Array[Mesh] = []
	for i in 8:
		asts.append(MeshFactory.asteroid(100 + i * 17, 3, 0.16))
	_meshes["asteroids"] = asts
	var asts_lo: Array[Mesh] = []
	for i in 8:
		asts_lo.append(MeshFactory.asteroid(100 + i * 17, 2, 0.16))
	_meshes["asteroids_lo"] = asts_lo
	_meshes["orb_sphere"] = MeshFactory.asteroid(1, 2, 0.0)
	var walls_l: Array[Mesh] = []
	var walls_r: Array[Mesh] = []
	for i in 3:
		walls_l.append(MeshFactory.canyon_wall(10 + i, -1))
		walls_r.append(MeshFactory.canyon_wall(20 + i, 1))
	_meshes["walls_l"] = walls_l
	_meshes["walls_r"] = walls_r
	var floors: Array[Mesh] = []
	for i in 3:
		floors.append(MeshFactory.terrain(40 + i))
	_meshes["floors"] = floors
	_meshes["spire"] = MeshFactory.spire(5)
	var shard := CylinderMesh.new()
	shard.top_radius = 0.0
	shard.bottom_radius = 0.5
	shard.height = 2.0
	shard.radial_segments = 6
	shard.rings = 1
	_meshes["shard"] = shard
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 12
	_meshes["ring"] = torus


func hazard_mesh(theme_kind: int, spec: ObstacleSpec) -> Mesh:
	match spec.kind:
		ObstacleSpec.Kind.SPHERE:
			if theme_kind == 2 or theme_kind == 5:
				return _meshes["orb_sphere"]
			return (_meshes["asteroids"] as Array)[spec.variant % 8]
		ObstacleSpec.Kind.BOX:
			return _meshes["box"]
		_:
			return _meshes["cyl"]


# --- spawning ---------------------------------------------------------------

func spawn(plan: ChunkPlan, parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Chunk%d" % plan.index
	root.position = Vector3(0, 0, plan.z_start)
	parent.add_child(root)
	plan.root = root
	var prof: ThemeProfile = profiles[plan.theme]
	var tm: Dictionary = materials.themes[plan.theme]
	for o in plan.obstacles:
		var spec := o as ObstacleSpec
		var node := pool.acquire(StringName("obs_%d" % spec.kind)) as ObstacleNode
		node.reparent(root, false)
		node.configure(spec, hazard_mesh(prof.dresser_kind, spec), (tm["hazard"] as Array)[spec.kind], ModuleLibrary.hazard_name(prof.dresser_kind, spec.kind))
	plan.pickup_alive = PackedByteArray()
	plan.pickup_alive.resize(plan.pickups.size())
	plan.pickup_alive.fill(1)
	plan.orb_mm = null
	if not plan.pickups.is_empty():
		var omi := pool.acquire(&"orbs") as MultiMeshInstance3D
		omi.reparent(root, false)
		omi.position = Vector3.ZERO
		var mm := omi.multimesh
		mm.visible_instance_count = mini(plan.pickups.size(), mm.instance_count)
		for i in mm.visible_instance_count:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, plan.pickups[i]))
		plan.orb_mm = omi
	var dress := pool.acquire(StringName("dress_%d" % prof.dresser_kind)) as Node3D
	dress.reparent(root, false)
	dress.position = Vector3.ZERO
	dress.call("randomize_layout", rng, plan.length, tm)
	root.set_meta("dressing", dress)


func despawn(plan: ChunkPlan) -> void:
	if plan.root == null:
		return
	for child in plan.root.get_children():
		if child.has_meta("pool_key"):
			child.reparent(_storage, false)
			pool.release(child)
	plan.root.queue_free()
	plan.root = null
	plan.orb_mm = null


## Hides orb i of the chunk (zero-scale instance).
func collect_orb(plan: ChunkPlan, i: int) -> void:
	plan.pickup_alive[i] = 0
	if plan.orb_mm:
		plan.orb_mm.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), plan.pickups[i]))


func _make_orbs() -> Node:
	var core := SphereMesh.new()
	core.radius = 0.32
	core.height = 0.64
	core.radial_segments = 12
	core.rings = 6
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.62
	ring.rings = 20
	ring.ring_segments = 5
	var mesh := MeshFactory.merge([[core, Transform3D.IDENTITY], [ring, Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3.ZERO)]])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 10
	var omi := MultiMeshInstance3D.new()
	omi.multimesh = mm
	var mat := materials.energy(Color(1.0, 0.76, 0.28), 3.6)
	mat.set_shader_parameter("spin", 3.0)
	omi.material_override = mat
	omi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return omi


func _make_dressing(kind: int) -> Node:
	var d := ChunkDressing.new()
	d.kind = kind
	d.meshes = _meshes
	d.materials = materials
	d.build()
	return d
