class_name NearMissSensor
extends RefCounted
## Tracks per-obstacle closest approach while the ship passes it. A near miss
## pays once per obstacle instance (ring frames share one id), only after the
## obstacle is fully behind the ship, and never for an obstacle we hit.

var threshold: float = 1.7
var ship_radius: float = 0.85
var _tracking: Dictionary = {}  # uid -> [min clearance, closest point]
var _paid: Dictionary = {}


func reset() -> void:
	_tracking.clear()
	_paid.clear()


## Clears in-flight tracking (e.g. on revive) but keeps paid ids.
func clear_tracking() -> void:
	_tracking.clear()


func was_paid(uid: int) -> bool:
	return _paid.has(uid)


## Samples every obstacle of the plans near the ship. Returns an array of
## events: { uid, clearance, point (world) }.
func update(ship_pos: Vector3, plans: Array) -> Array:
	var events: Array = []
	for p in plans:
		var plan := p as ChunkPlan
		if ship_pos.z > plan.z_start + 12.0 or ship_pos.z < plan.z_end() - 12.0:
			continue
		var local := ship_pos - Vector3(0, 0, plan.z_start)
		for o in plan.obstacles:
			var spec := o as ObstacleSpec
			var ev := sample(local, spec, plan.uid_for(spec), plan.z_start)
			if not ev.is_empty():
				events.append(ev)
	return events


func sample(local: Vector3, spec: ObstacleSpec, uid: int, z_offset: float = 0.0) -> Dictionary:
	var hz := spec.half_z()
	var near_side := spec.center.z + hz
	var far_side := spec.center.z - hz
	var passed := local.z < far_side - ship_radius
	if not passed:
		if local.z - near_side < 10.0:
			var clearance := spec.surface_distance(local) - ship_radius
			var prev: Array = _tracking.get(uid, [INF, Vector3.ZERO])
			if clearance < prev[0]:
				_tracking[uid] = [clearance, local + Vector3(0, 0, z_offset)]
		return {}
	if _tracking.has(uid):
		var rec: Array = _tracking[uid]
		_tracking.erase(uid)
		if rec[0] < threshold and rec[0] > 0.0 and not _paid.has(uid):
			_paid[uid] = true
			return {"uid": uid, "clearance": rec[0], "point": rec[1]}
	return {}
