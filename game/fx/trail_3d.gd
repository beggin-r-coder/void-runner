class_name Trail3D
extends MeshInstance3D
## Camera-facing ribbon trail built from the emitter's recent world positions.

var emitter: Node3D
var camera: Camera3D
var width: float = 0.25
var max_points: int = 22
var _points: PackedVector3Array = PackedVector3Array()
var _im: ImmediateMesh


func _init() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	extra_cull_margin = 200.0


func clear() -> void:
	_points.clear()
	_im.clear_surfaces()


func shift(dz: float) -> void:
	for i in _points.size():
		_points[i].z += dz


func sample() -> void:
	if emitter == null or not emitter.is_inside_tree():
		return
	_points.insert(0, emitter.global_position)
	if _points.size() > max_points:
		_points.resize(max_points)


func _process(_delta: float) -> void:
	_im.clear_surfaces()
	if _points.size() < 2 or camera == null or not visible:
		return
	global_transform = Transform3D.IDENTITY
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material_override)
	var cam_pos := camera.global_position
	var n := _points.size()
	for i in n:
		var p := _points[i]
		var tangent := (_points[maxi(i - 1, 0)] - _points[mini(i + 1, n - 1)]).normalized()
		var to_cam := (cam_pos - p).normalized()
		var side := tangent.cross(to_cam).normalized() * width * (1.0 - float(i) / n * 0.6)
		var u := float(i) / (n - 1)
		_im.surface_set_uv(Vector2(u, 0.0))
		_im.surface_add_vertex(p - side)
		_im.surface_set_uv(Vector2(u, 1.0))
		_im.surface_add_vertex(p + side)
	_im.surface_end()
