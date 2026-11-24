class_name ObstacleSpec
extends RefCounted
## Pure-data hazard volume in chunk-local space (z runs 0 -> -length).
## size meaning per kind:
##   BOX:    half extents
##   SPHERE: x = radius
##   CYL_V:  x = radius, y = half height (axis = Y)
##   CYL_H:  x = half length (axis = X), y = radius

enum Kind { BOX, SPHERE, CYL_V, CYL_H }

var kind: int = Kind.BOX
var center: Vector3 = Vector3.ZERO
var size: Vector3 = Vector3.ONE
var group_id: int = 0
var variant: int = 0


static func box(c: Vector3, half: Vector3, group: int) -> ObstacleSpec:
	return _make(Kind.BOX, c, half, group)


static func box_span(x0: float, x1: float, y0: float, y1: float, z: float, depth: float, group: int) -> ObstacleSpec:
	var c := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z)
	var h := Vector3(absf(x1 - x0) * 0.5, absf(y1 - y0) * 0.5, depth * 0.5)
	return _make(Kind.BOX, c, h, group)


static func sphere(c: Vector3, r: float, group: int) -> ObstacleSpec:
	return _make(Kind.SPHERE, c, Vector3(r, r, r), group)


static func pillar(c: Vector3, r: float, half_h: float, group: int) -> ObstacleSpec:
	return _make(Kind.CYL_V, c, Vector3(r, half_h, r), group)


static func beam(c: Vector3, half_len: float, r: float, group: int) -> ObstacleSpec:
	return _make(Kind.CYL_H, c, Vector3(half_len, r, r), group)


static func _make(k: int, c: Vector3, s: Vector3, group: int) -> ObstacleSpec:
	var o := ObstacleSpec.new()
	o.kind = k
	o.center = c
	o.size = s
	o.group_id = group
	return o


func half_z() -> float:
	match kind:
		Kind.BOX:
			return size.z
		Kind.SPHERE, Kind.CYL_V:
			return size.x
		_:
			return size.y


## Signed distance from point p (chunk-local) to the hazard surface.
func surface_distance(p: Vector3) -> float:
	var q := p - center
	match kind:
		Kind.BOX:
			var a := q.abs() - size
			var outside := Vector3(maxf(a.x, 0.0), maxf(a.y, 0.0), maxf(a.z, 0.0)).length()
			var inside := minf(maxf(a.x, maxf(a.y, a.z)), 0.0)
			return outside + inside
		Kind.SPHERE:
			return q.length() - size.x
		Kind.CYL_V:
			var dr := Vector2(q.x, q.z).length() - size.x
			var dy := absf(q.y) - size.y
			return Vector2(maxf(dr, 0.0), maxf(dy, 0.0)).length() + minf(maxf(dr, dy), 0.0)
		_:
			var dr2 := Vector2(q.y, q.z).length() - size.y
			var dx := absf(q.x) - size.x
			return Vector2(maxf(dr2, 0.0), maxf(dx, 0.0)).length() + minf(maxf(dr2, dx), 0.0)
