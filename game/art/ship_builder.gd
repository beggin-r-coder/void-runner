class_name ShipBuilder
extends RefCounted
## Builds the hero ship from procedural parts. Every livery shares the same
## silhouette footprint and collision size (fairness across skins).

const LIVERIES := {
	"nova": {"name": "NOVA", "hull": Color(0.86, 0.89, 0.93), "trim": Color(0.1, 0.11, 0.14), "accent": Color(0.2, 0.85, 1.0), "flame": Color(0.3, 0.65, 1.0), "cost": 0},
	"ember": {"name": "EMBER", "hull": Color(0.16, 0.16, 0.18), "trim": Color(0.35, 0.33, 0.32), "accent": Color(1.0, 0.42, 0.08), "flame": Color(1.0, 0.5, 0.15), "cost": 400},
	"phantom": {"name": "PHANTOM", "hull": Color(0.3, 0.1, 0.42), "trim": Color(0.06, 0.05, 0.08), "accent": Color(1.0, 0.2, 0.8), "flame": Color(0.85, 0.3, 1.0), "cost": 900},
}
const ORDER := ["nova", "ember", "phantom"]


## Returns { root, flames: Array[MeshInstance3D], wingtips: Array[Node3D], nozzles: Array[Node3D] }
static func build(livery_id: String, mats: GameMaterials) -> Dictionary:
	var lv: Dictionary = LIVERIES.get(livery_id, LIVERIES["nova"])
	var root := Node3D.new()
	root.name = "ShipVisual"

	var hull := StandardMaterial3D.new()
	hull.albedo_color = lv["hull"]
	hull.metallic = 0.45
	hull.roughness = 0.32
	hull.rim_enabled = true
	hull.rim = 0.35
	hull.clearcoat_enabled = true
	hull.clearcoat = 0.6
	var trim := StandardMaterial3D.new()
	trim.albedo_color = lv["trim"]
	trim.metallic = 0.9
	trim.roughness = 0.4
	var accent := StandardMaterial3D.new()
	accent.albedo_color = (lv["accent"] as Color).darkened(0.3)
	accent.emission_enabled = true
	accent.emission = lv["accent"]
	accent.emission_energy_multiplier = 5.0
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.03, 0.06, 0.1)
	glass.metallic = 1.0
	glass.roughness = 0.05
	glass.emission_enabled = true
	glass.emission = (lv["accent"] as Color) * 0.25
	glass.rim_enabled = true
	glass.rim = 1.0

	# Fuselage: faceted tapered hexagonal body, nose toward -Z.
	var body := CylinderMesh.new()
	body.top_radius = 0.06
	body.bottom_radius = 0.5
	body.height = 3.2
	body.radial_segments = 6
	body.rings = 1
	_part(root, body, hull, Vector3(0, 0, -0.35), Vector3(-90, 0, 0), Vector3(1.15, 1.0, 0.5))

	var spine := CylinderMesh.new()
	spine.top_radius = 0.02
	spine.bottom_radius = 0.22
	spine.height = 2.2
	spine.radial_segments = 4
	spine.rings = 1
	_part(root, spine, trim, Vector3(0, 0.14, 0.1), Vector3(-90, 0, 0), Vector3(1.0, 1.0, 0.8))

	var rear := BoxMesh.new()
	rear.size = Vector3(1.05, 0.42, 0.9)
	_part(root, rear, trim, Vector3(0, 0, 1.15))

	# Cockpit canopy
	var canopy := SphereMesh.new()
	canopy.radius = 0.5
	canopy.height = 1.0
	canopy.radial_segments = 20
	canopy.rings = 10
	_part(root, canopy, glass, Vector3(0, 0.2, -0.55), Vector3.ZERO, Vector3(0.36, 0.26, 0.85))

	# Delta wings with slight dihedral and swept tips.
	var wing_poly := PackedVector2Array([Vector2(0.25, -0.5), Vector2(1.95, 0.85), Vector2(2.05, 1.25), Vector2(1.6, 1.3), Vector2(0.25, 1.15)])
	var wing := MeshFactory.extrude(wing_poly, 0.07)
	for s in [-1.0, 1.0]:
		var w := _part(root, wing, hull, Vector3(0, -0.05, 0.0), Vector3(0, 0, 6.0 * s), Vector3(s, 1, 1))
		w.name = "Wing"
		# trailing-edge light strip
		var strip := BoxMesh.new()
		strip.size = Vector3(1.35, 0.05, 0.06)
		_part(root, strip, accent, Vector3(0.95 * s, 0.03, 1.2))
		# wing pylons
		var pod := CylinderMesh.new()
		pod.top_radius = 0.06
		pod.bottom_radius = 0.1
		pod.height = 1.3
		pod.radial_segments = 8
		_part(root, pod, trim, Vector3(1.95 * s, 0.12, 0.55), Vector3(-90, 0, 0))
		# canards
		var can_poly := PackedVector2Array([Vector2(0.2, -1.2), Vector2(0.75, -0.75), Vector2(0.75, -0.6), Vector2(0.2, -0.65)])
		_part(root, MeshFactory.extrude(can_poly, 0.05), hull, Vector3(0, 0.02, 0), Vector3(0, 0, 4.0 * s), Vector3(s, 1, 1))
		# tail fins canted outward
		var fin_poly := PackedVector2Array([Vector2(0.0, 0.35), Vector2(0.75, 1.15), Vector2(0.75, 1.45), Vector2(0.0, 1.35)])
		var fin := MeshFactory.extrude(fin_poly, 0.05)
		_part(root, fin, hull, Vector3(0.45 * s, 0.15, 0.0), Vector3(0, 0, 70.0 * s), Vector3(s, 1, 1))

	# Engines
	var flames: Array[MeshInstance3D] = []
	var nozzles: Array[Node3D] = []
	var flame_mat := mats.flame(lv["flame"])
	var glow_mat := mats.energy(lv["flame"], 6.0)
	for s in [-1.0, 1.0]:
		var nac := CylinderMesh.new()
		nac.top_radius = 0.2
		nac.bottom_radius = 0.24
		nac.height = 1.2
		nac.radial_segments = 14
		_part(root, nac, trim, Vector3(0.36 * s, -0.02, 1.15), Vector3(-90, 0, 0))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.15
		ring.outer_radius = 0.23
		ring.rings = 16
		ring.ring_segments = 8
		_part(root, ring, accent, Vector3(0.36 * s, -0.02, 1.76), Vector3(90, 0, 0))
		var core := SphereMesh.new()
		core.radius = 0.16
		core.height = 0.1
		_part(root, core, glow_mat, Vector3(0.36 * s, -0.02, 1.76))
		var plume := CylinderMesh.new()
		plume.top_radius = 0.17
		plume.bottom_radius = 0.02
		plume.height = 1.0
		plume.radial_segments = 12
		plume.rings = 4
		var pivot := Node3D.new()
		pivot.position = Vector3(0.36 * s, -0.02, 1.8)
		root.add_child(pivot)
		var flame := MeshInstance3D.new()
		flame.mesh = plume
		flame.material_override = flame_mat
		flame.rotation_degrees = Vector3(90, 0, 0)
		flame.position = Vector3(0, 0, 0.5)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(flame)
		flames.append(flame)
		nozzles.append(pivot)

	var wingtips: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var tip := Node3D.new()
		tip.position = Vector3(2.0 * s, 0.0, 1.2)
		root.add_child(tip)
		wingtips.append(tip)
		var light := SphereMesh.new()
		light.radius = 0.06
		light.height = 0.12
		_part(root, light, accent, Vector3(1.95 * s, 0.12, -0.12))

	# cinematic key light that follows the ship (also grazes passing hazards)
	var key := OmniLight3D.new()
	key.position = Vector3(0.0, 2.6, 3.2)
	key.omni_range = 9.0
	key.light_energy = 1.4
	key.light_color = Color(0.95, 0.97, 1.0)
	key.shadow_enabled = false
	root.add_child(key)

	return {"root": root, "flames": flames, "wingtips": wingtips, "nozzles": nozzles, "accent": lv["accent"], "flame_color": lv["flame"]}


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi
