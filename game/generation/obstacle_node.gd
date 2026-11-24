class_name ObstacleNode
extends StaticBody3D
## Pooled hazard: one StaticBody with a collision shape sized exactly to the
## ObstacleSpec and a unit visual mesh scaled to match.

var kind: int
var spec: ObstacleSpec
var hazard_name: String = ""
var mesh_instance: MeshInstance3D
var shape_node: CollisionShape3D


func _init(p_kind: int) -> void:
	kind = p_kind
	collision_layer = 2
	collision_mask = 0
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	shape_node = CollisionShape3D.new()
	match kind:
		ObstacleSpec.Kind.BOX:
			shape_node.shape = BoxShape3D.new()
		ObstacleSpec.Kind.SPHERE:
			shape_node.shape = SphereShape3D.new()
		_:
			shape_node.shape = CylinderShape3D.new()
	add_child(shape_node)


func configure(p_spec: ObstacleSpec, mesh: Mesh, mat: Material, p_name: String) -> void:
	spec = p_spec
	hazard_name = p_name
	position = spec.center
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.rotation = Vector3.ZERO
	shape_node.rotation = Vector3.ZERO
	match kind:
		ObstacleSpec.Kind.BOX:
			(shape_node.shape as BoxShape3D).size = spec.size * 2.0
			mesh_instance.scale = spec.size
		ObstacleSpec.Kind.SPHERE:
			(shape_node.shape as SphereShape3D).radius = spec.size.x * 0.94
			mesh_instance.scale = Vector3.ONE * spec.size.x
		ObstacleSpec.Kind.CYL_V:
			var c := shape_node.shape as CylinderShape3D
			c.radius = spec.size.x
			c.height = spec.size.y * 2.0
			mesh_instance.scale = Vector3(spec.size.x, spec.size.y, spec.size.x)
		ObstacleSpec.Kind.CYL_H:
			var c2 := shape_node.shape as CylinderShape3D
			c2.radius = spec.size.y
			c2.height = spec.size.x * 2.0
			shape_node.rotation = Vector3(0, 0, PI * 0.5)
			mesh_instance.rotation = Vector3(0, 0, PI * 0.5)
			mesh_instance.scale = Vector3(spec.size.y, spec.size.x, spec.size.y)


func on_acquire() -> void:
	visible = true
	shape_node.set_deferred("disabled", false)


func on_release() -> void:
	visible = false
	shape_node.set_deferred("disabled", true)
