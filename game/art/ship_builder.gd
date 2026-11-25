class_name ShipBuilder
extends RefCounted
## Builds the "Void Runner" interceptor from procedural parts: faceted lofted
## fuselage with chines, gem-cut canopy, cranked arrow wings with anhedral tip
## fins, twin lofted engine pods with petal nozzles and spinning turbines,
## wingtip RCS thrusters and nav lights. Every livery shares the same
## silhouette and collision size (fairness across skins).

const LIVERIES := {
	"nova": {"name": "NOVA", "hull": Color(0.88, 0.9, 0.94), "under": Color(0.09, 0.12, 0.18), "trim": Color(0.12, 0.13, 0.16), "accent": Color(0.2, 0.85, 1.0), "flame": Color(0.3, 0.65, 1.0), "cost": 0},
	"ember": {"name": "EMBER", "hull": Color(0.13, 0.13, 0.15), "under": Color(0.55, 0.18, 0.05), "trim": Color(0.3, 0.29, 0.28), "accent": Color(1.0, 0.45, 0.08), "flame": Color(1.0, 0.5, 0.15), "cost": 400},
	"phantom": {"name": "PHANTOM", "hull": Color(0.32, 0.12, 0.46), "under": Color(0.05, 0.04, 0.08), "trim": Color(0.07, 0.06, 0.09), "accent": Color(1.0, 0.25, 0.8), "flame": Color(0.85, 0.3, 1.0), "cost": 900},
}
const ORDER := ["nova", "ember", "phantom"]
const HULL_SHADER := preload("res://game/art/shaders/ship_hull.gdshader")

## Chined cross-section: sharp side edges, raised spine, flatter belly.
const CHINE := [Vector2(1.0, 0.0), Vector2(0.62, 0.55), Vector2(0.18, 0.95), Vector2(-0.18, 0.95), Vector2(-0.62, 0.55), Vector2(-1.0, 0.0), Vector2(-0.6, -0.5), Vector2(0.0, -0.72), Vector2(0.6, -0.5)]
const CANOPY := [Vector2(1.0, 0.0), Vector2(0.55, 0.75), Vector2(0.0, 1.0), Vector2(-0.55, 0.75), Vector2(-1.0, 0.0), Vector2(0.0, -0.2)]


static func _hull_mat(lv: Dictionary, stripe: float = 1.0, split: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HULL_SHADER
	m.set_shader_parameter("top_color", lv["hull"])
	m.set_shader_parameter("under_color", lv["under"])
	m.set_shader_parameter("accent", lv["accent"])
	m.set_shader_parameter("stripe", stripe)
	m.set_shader_parameter("split", split)
	return m


static func _std(color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


## Returns { root, flames, wingtips, nozzles, petals, turbines, heat_rings,
##           rcs: {left, right}, strobes, accent, flame_color }
static func build(livery_id: String, mats: GameMaterials) -> Dictionary:
	var lv: Dictionary = LIVERIES.get(livery_id, LIVERIES["nova"])
	var accent_c: Color = lv["accent"]
	var flame_c: Color = lv["flame"]
	var root := Node3D.new()
	root.name = "ShipVisual"

	var hull := _hull_mat(lv)
	var hull_plain := _hull_mat(lv, 0.0)
	var wing_mat := _hull_mat(lv, 0.0)
	wing_mat.set_shader_parameter("band_pos", 1.45)
	wing_mat.set_shader_parameter("band_width", 0.09)
	var trim := _std(lv["trim"], 0.85, 0.42)
	var dark := _std(Color(0.03, 0.035, 0.045), 0.6, 0.6)
	var accent := _std(accent_c.darkened(0.3), 0.2, 0.4, accent_c, 5.0)
	var glass := _std(Color(0.02, 0.05, 0.09), 1.0, 0.04, accent_c * 0.35, 1.0)
	glass.rim_enabled = true
	glass.rim = 1.0

	# --- fuselage: needle nose -> cockpit -> wide engine deck ---------------------
	var fus := MeshFactory.loft([
		[-2.35, 0.02, 0.015, 0.0],
		[-1.95, 0.13, 0.08, 0.0],
		[-1.35, 0.3, 0.17, 0.02],
		[-0.65, 0.42, 0.25, 0.04],
		[0.15, 0.52, 0.26, 0.03],
		[0.95, 0.6, 0.22, 0.0],
		[1.5, 0.48, 0.17, 0.0],
	], PackedVector2Array(CHINE))
	_part(root, fus, hull)

	# glowing chine lines along both sides of the nose
	for s in [-1.0, 1.0]:
		var chine := BoxMesh.new()
		chine.size = Vector3(0.02, 0.02, 1.3)
		_part(root, chine, accent, Vector3(0.36 * s, 0.03, -1.0), Vector3(0, -12.0 * s, 0))

	# gem-cut canopy sitting on the spine
	var can := MeshFactory.loft([
		[-1.25, 0.03, 0.02, 0.17],
		[-0.95, 0.15, 0.12, 0.19],
		[-0.45, 0.19, 0.17, 0.22],
		[-0.05, 0.14, 0.11, 0.22],
		[0.2, 0.05, 0.03, 0.22],
	], PackedVector2Array(CANOPY))
	_part(root, can, glass)
	var frame := BoxMesh.new()
	frame.size = Vector3(0.36, 0.025, 0.03)
	_part(root, frame, trim, Vector3(0, 0.36, -0.55), Vector3(-6, 0, 0))

	# --- wings: cranked arrow, thin, with glowing leading edges --------------------
	var wing_poly := PackedVector2Array([Vector2(0.35, -0.75), Vector2(1.05, 0.12), Vector2(2.05, 0.72), Vector2(2.12, 1.02), Vector2(1.35, 0.96), Vector2(0.95, 1.18), Vector2(0.4, 1.22)])
	var wing := MeshFactory.extrude(wing_poly, 0.055)
	for s in [-1.0, 1.0]:
		var wi := _part(root, wing, wing_mat, Vector3(0, -0.04, 0.0), Vector3(0, 0, 4.0 * s), Vector3(s, 1, 1))
		wi.name = "Wing"
		_edge(root, Vector3(0.38 * s, 0.0, -0.72), Vector3(1.05 * s, 0.05, 0.12), accent, 0.025)
		_edge(root, Vector3(1.05 * s, 0.05, 0.12), Vector3(2.04 * s, 0.11, 0.72), accent, 0.025)
		# anhedral tip fin
		var fin_poly := PackedVector2Array([Vector2(0.0, 0.62), Vector2(0.38, 0.9), Vector2(0.38, 1.12), Vector2(0.0, 1.05)])
		_part(root, MeshFactory.extrude(fin_poly, 0.04), hull_plain, Vector3(2.08 * s, 0.11, 0.0), Vector3(0, 0, (-90.0 - 35.0) * s), Vector3(s, 1, 1))
		# canard
		var can_poly := PackedVector2Array([Vector2(0.24, -1.45), Vector2(0.72, -1.05), Vector2(0.72, -0.9), Vector2(0.26, -0.95)])
		_part(root, MeshFactory.extrude(can_poly, 0.035), hull_plain, Vector3(0, 0.02, 0), Vector3(0, 0, 6.0 * s), Vector3(s, 1, 1))
		# swept twin tail fins, canted out
		var tail_poly := PackedVector2Array([Vector2(0.0, 0.55), Vector2(0.62, 1.12), Vector2(0.66, 1.42), Vector2(0.0, 1.38)])
		var tf := _part(root, MeshFactory.extrude(tail_poly, 0.045), hull_plain, Vector3(0.3 * s, 0.17, 0.05), Vector3(0, 0, 68.0 * s), Vector3(s, 1, 1))
		var tip := BoxMesh.new()
		tip.size = Vector3(0.03, 0.03, 0.3)
		var tl := MeshInstance3D.new()
		tl.mesh = tip
		tl.material_override = accent
		tl.position = Vector3(0.0, 0.0, 0.0)
		tf.add_child(tl)
		tl.position = Vector3(0.64, 0.0, 1.27)
		# dark intake wedge at the wing root
		var intake := MeshFactory.loft([[-0.35, 0.05, 0.06, 0.0], [-0.15, 0.13, 0.11, 0.0], [0.15, 0.13, 0.11, 0.0]], MeshFactory.ngon(6, PI / 6.0))
		_part(root, intake, dark, Vector3(0.5 * s, -0.04, 0.0))

	# --- engines -----------------------------------------------------------------
	var flames: Array[MeshInstance3D] = []
	var nozzles: Array[Node3D] = []
	var petals: Array[Node3D] = []
	var turbines: Array[Node3D] = []
	var heat_rings: Array[MeshInstance3D] = []
	var plume_mesh := MeshFactory.plume()
	var glow_mat := mats.energy(flame_c, 4.0)
	var pod := MeshFactory.loft([
		[-0.15, 0.17, 0.17, 0.0],
		[0.3, 0.23, 0.22, 0.0],
		[1.2, 0.25, 0.24, 0.0],
		[1.62, 0.22, 0.21, 0.0],
	], MeshFactory.ngon(10, PI / 10.0))
	var petal_mesh := BoxMesh.new()
	petal_mesh.size = Vector3(0.11, 0.014, 0.2)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.025, 0.16, 0.012)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.17
	ring_mesh.outer_radius = 0.2
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 6
	for s in [-1.0, 1.0]:
		var ex := Vector3(0.42 * s, -0.02, 0.0)
		_part(root, pod, hull_plain, ex)
		var intake_disc := CylinderMesh.new()
		intake_disc.top_radius = 0.15
		intake_disc.bottom_radius = 0.15
		intake_disc.height = 0.02
		_part(root, intake_disc, dark, ex + Vector3(0, 0, -0.16), Vector3(90, 0, 0))
		var band := TorusMesh.new()
		band.inner_radius = 0.235
		band.outer_radius = 0.26
		band.rings = 20
		band.ring_segments = 6
		_part(root, band, accent, ex + Vector3(0, 0, 1.05), Vector3(90, 0, 0))
		# nozzle: dark shroud, petals that iris open with throttle, turbine, heat ring
		var nz := Node3D.new()
		nz.position = ex + Vector3(0, 0, 1.62)
		root.add_child(nz)
		var throat := CylinderMesh.new()
		throat.top_radius = 0.16
		throat.bottom_radius = 0.16
		throat.height = 0.04
		_part(nz, throat, glow_mat, Vector3(0, 0, 0.0), Vector3(90, 0, 0))
		for i in 10:
			var holder := Node3D.new()
			holder.rotation = Vector3(0, 0, TAU * i / 10.0)
			nz.add_child(holder)
			var hinge := Node3D.new()
			hinge.position = Vector3(0, 0.205, 0.0)
			holder.add_child(hinge)
			var pm := MeshInstance3D.new()
			pm.mesh = petal_mesh
			pm.material_override = trim
			pm.position = Vector3(0, 0, 0.1)
			hinge.add_child(pm)
			petals.append(hinge)
		var turb := Node3D.new()
		turb.position = Vector3(0, 0, 0.03)
		nz.add_child(turb)
		for i in 6:
			var bl := MeshInstance3D.new()
			bl.mesh = blade
			bl.material_override = glow_mat
			bl.rotation = Vector3(0.0, 0.35, TAU * i / 6.0)
			bl.position = Vector3(0, 0, 0)
			turb.add_child(bl)
		turbines.append(turb)
		var hr := MeshInstance3D.new()
		hr.mesh = ring_mesh
		hr.material_override = mats.energy(flame_c, 1.5)
		hr.rotation_degrees = Vector3(90, 0, 0)
		hr.position = Vector3(0, 0, 0.2)
		hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nz.add_child(hr)
		heat_rings.append(hr)
		# plume (core + sheath), as before
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0, 0.05)
		nz.add_child(pivot)
		var flame := MeshInstance3D.new()
		flame.mesh = plume_mesh
		flame.material_override = mats.flame(flame_c, 0.37 + s * 0.21)
		(flame.material_override as ShaderMaterial).set_shader_parameter("radius_scale", 0.19)
		flame.scale = Vector3(0.19, 0.19, 1.0)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.extra_cull_margin = 2.0
		pivot.add_child(flame)
		var sheath := MeshInstance3D.new()
		sheath.mesh = plume_mesh
		sheath.material_override = mats.flame(flame_c, 0.91 + s * 0.17, true)
		(sheath.material_override as ShaderMaterial).set_shader_parameter("radius_scale", 0.19 * 1.75)
		sheath.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheath.extra_cull_margin = 2.0
		flame.add_child(sheath)
		sheath.scale = Vector3(1.75, 1.75, 1.2)
		flames.append(flame)
		nozzles.append(pivot)

	# --- wingtip RCS thrusters (fire sideways when the ship accelerates) -----------
	var rcs := {}
	var wingtips: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var tipn := Node3D.new()
		tipn.position = Vector3(2.12 * s, 0.11, 0.88)
		root.add_child(tipn)
		wingtips.append(tipn)
		var jet := MeshInstance3D.new()
		jet.mesh = plume_mesh
		jet.material_override = mats.flame(accent_c.lerp(Color.WHITE, 0.3), 2.3 + s)
		(jet.material_override as ShaderMaterial).set_shader_parameter("radius_scale", 0.05)
		(jet.material_override as ShaderMaterial).set_shader_parameter("flow_speed", 11.0)
		jet.rotation_degrees = Vector3(0, 90.0 * s, 0)
		jet.scale = Vector3(0.05, 0.05, 0.05)
		jet.visible = false
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tipn.add_child(jet)
		rcs["left" if s < 0.0 else "right"] = jet
		# nav light: red port, green starboard
		var nav := SphereMesh.new()
		nav.radius = 0.045
		nav.height = 0.09
		var nav_col := Color(1.0, 0.15, 0.12) if s < 0.0 else Color(0.2, 1.0, 0.35)
		_part(root, nav, mats.energy(nav_col, 5.0), Vector3(2.09 * s, 0.12, 0.66))
	var strobe := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	strobe.mesh = sm
	strobe.material_override = mats.energy(Color(1, 1, 1), 9.0)
	strobe.position = Vector3(0, 0.22, 1.48)
	strobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(strobe)
	# soft under-glow strip
	var under := BoxMesh.new()
	under.size = Vector3(0.05, 0.02, 1.6)
	_part(root, under, accent, Vector3(0, -0.17, 0.1))

	# cinematic key light that follows the ship (also grazes passing hazards)
	var key := OmniLight3D.new()
	key.position = Vector3(0.0, 2.6, 3.2)
	key.omni_range = 10.0
	key.light_energy = 3.2
	key.light_color = Color(0.95, 0.97, 1.0)
	key.shadow_enabled = false
	root.add_child(key)

	return {"root": root, "flames": flames, "wingtips": wingtips, "nozzles": nozzles, "petals": petals, "turbines": turbines, "heat_rings": heat_rings, "rcs": rcs, "strobes": [strobe], "accent": accent_c, "flame_color": flame_c}


## Thin glowing bar between two points (leading-edge lights).
static func _edge(parent: Node3D, a: Vector3, b: Vector3, mat: Material, thick: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, thick, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	mi.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi
