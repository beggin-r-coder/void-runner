class_name ReachGrid
extends RefCounted
## Controller-aware fairness validator.
## The flight cross-section is voxelized into cells. Obstacles are inflated by
## ship radius + safety margin; reachable cells propagate forward slice by
## slice, dilated by how far the ship can actually move laterally between
## slices at the chunk's speed. A chain with no continuous reachable cell
## sequence is rejected - a visible gap alone is not proof of reachability.

const CELL := 1.0
const STEP := 2.0

var cols: int
var rows: int
var x0: float
var y0: float


func _init(half_w: float = 8.0, half_h: float = 4.5) -> void:
	cols = int(floor(half_w * 2.0 / CELL)) + 1
	rows = int(floor(half_h * 2.0 / CELL)) + 1
	x0 = -half_w
	y0 = -half_h


func cell_count() -> int:
	return cols * rows


func cell_pos(i: int) -> Vector2:
	return Vector2(x0 + (i % cols) * CELL, y0 + (i / cols) * CELL)


func cell_index(p: Vector2) -> int:
	var i := clampi(int(round((p.x - x0) / CELL)), 0, cols - 1)
	var j := clampi(int(round((p.y - y0) / CELL)), 0, rows - 1)
	return j * cols + i


func full() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(cols * rows)
	m.fill(1)
	return m


static func count(m: PackedByteArray) -> int:
	var c := 0
	for v in m:
		c += v
	return c


func free_mask(obstacles: Array, z: float, inflate: float) -> PackedByteArray:
	var near: Array = []
	for o in obstacles:
		var spec := o as ObstacleSpec
		if absf(spec.center.z - z) <= spec.half_z() + inflate:
			near.append(spec)
	var m := full()
	if near.is_empty():
		return m
	for i in m.size():
		var c := cell_pos(i)
		var p := Vector3(c.x, c.y, z)
		for spec in near:
			if (spec as ObstacleSpec).surface_distance(p) < inflate:
				m[i] = 0
				break
	return m


func dilate(m: PackedByteArray, kx: int, ky: int) -> PackedByteArray:
	var out := m
	if kx > 0:
		var tmp := PackedByteArray()
		tmp.resize(m.size())
		for j in rows:
			for i in cols:
				var v := 0
				for d in range(maxi(i - kx, 0), mini(i + kx, cols - 1) + 1):
					if out[j * cols + d] == 1:
						v = 1
						break
				tmp[j * cols + i] = v
		out = tmp
	if ky > 0:
		var tmp2 := PackedByteArray()
		tmp2.resize(m.size())
		for j in rows:
			for i in cols:
				var v2 := 0
				for d in range(maxi(j - ky, 0), mini(j + ky, rows - 1) + 1):
					if out[d * cols + i] == 1:
						v2 = 1
						break
				tmp2[j * cols + i] = v2
		out = tmp2
	return out


static func intersect(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(a.size())
	for i in a.size():
		out[i] = a[i] & b[i]
	return out


## Lateral distance coverable in time t at sustained speed (conservative).
static func lateral_reach(t: float, v_max: float, accel: float) -> float:
	var t_ramp := v_max / accel
	if t <= t_ramp:
		return 0.5 * accel * t * t
	return v_max * t - 0.5 * v_max * t_ramp


## Propagates an entry set through a chunk from z_from down to z_to.
## Returns { ok, exit, slices, steps, zs }.
func propagate(entry: PackedByteArray, obstacles: Array, z_from: float, z_to: float, speed: float, cfg: HandlingConfig) -> Dictionary:
	var inflate := cfg.ship_radius + cfg.safety_margin
	var t := STEP / maxf(speed, 1.0)
	var vx := cfg.max_lateral_speed * cfg.reach_efficiency
	var vy := cfg.max_vertical_speed * cfg.reach_efficiency
	var dx := vx * t
	var dy := vy * t
	var reach := entry
	var ax := 0.0
	var ay := 0.0
	var slices: Array = []
	var steps: Array = []
	var zs := PackedFloat32Array()
	var z := z_from
	while z > z_to + 0.001:
		z = maxf(z - STEP, z_to)
		ax += dx / CELL
		ay += dy / CELL
		var kx := int(ax)
		var ky := int(ay)
		ax -= kx
		ay -= ky
		if kx > 0 or ky > 0:
			reach = dilate(reach, kx, ky)
		reach = intersect(reach, free_mask(obstacles, z, inflate))
		slices.append(reach)
		steps.append(Vector2i(kx, ky))
		zs.append(z)
		if count(reach) == 0:
			return {"ok": false, "exit": reach, "slices": slices, "steps": steps, "zs": zs}
	return {"ok": true, "exit": reach, "slices": slices, "steps": steps, "zs": zs}


func nearest_cell(m: PackedByteArray, target: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in m.size():
		if m[i] == 1:
			var d := cell_pos(i).distance_squared_to(target)
			if d < best_d:
				best_d = d
				best = i
	return best


## Cells (Chebyshev, max 3) from idx to the nearest unreachable cell in m.
## The envelope edge is not a hazard (the ship just clamps there).
func clearance(m: PackedByteArray, idx: int) -> int:
	var ci := idx % cols
	var cj := idx / cols
	for r in range(1, 4):
		for j in range(cj - r, cj + r + 1):
			for i in range(ci - r, ci + r + 1):
				if absi(i - ci) != r and absi(j - cj) != r:
					continue
				if i < 0 or j < 0 or i >= cols or j >= rows:
					continue
				if m[j * cols + i] == 0:
					return r - 1
	return 3


func _near_obstacles(obstacles: Array, z: float) -> Array:
	var near: Array = []
	for o in obstacles:
		var spec := o as ObstacleSpec
		if absf(spec.center.z - z) <= spec.half_z() + 6.0:
			near.append(spec)
	return near


## Metres of free space around a cell (capped at 3), from real obstacle distance
## sampled at this slice and the neighbouring ones.
func _obstacle_room(near: Array, c: Vector2, z: float) -> float:
	var room := 3.0
	for spec in near:
		for dz in [-2.0, 0.0, 2.0]:
			room = minf(room, (spec as ObstacleSpec).surface_distance(Vector3(c.x, c.y, z + dz)))
	return clampf(room, 0.0, 3.0)


func _roomiest_cell(m: PackedByteArray, prefer: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in m.size():
		if m[i] == 1:
			var d := cell_pos(i).distance_squared_to(prefer) * 0.05 - clearance(m, i) * 6.0
			if d < best_d:
				best_d = d
				best = i
	return best


## Walks back through a successful propagation to produce one certified
## route (x, y, z points), preferring to stay near `prefer`.
func backtrack(result: Dictionary, prefer: Vector2, obstacles: Array = []) -> PackedVector3Array:
	var slices: Array = result["slices"]
	var steps: Array = result["steps"]
	var zs: PackedFloat32Array = result["zs"]
	var path := PackedVector3Array()
	var n := slices.size()
	if n == 0:
		return path
	var cur := _roomiest_cell(slices[n - 1], prefer)
	var cells: Array[int] = [cur]
	var last_move := Vector2i.ZERO
	for k in range(n - 1, 0, -1):
		var st: Vector2i = steps[k]
		var prev: PackedByteArray = slices[k - 1]
		var ci := cur % cols
		var cj := cur / cols
		var best := -1
		var best_d := INF
		var near := _near_obstacles(obstacles, zs[k - 1])
		for j in range(maxi(cj - st.y, 0), mini(cj + st.y, rows - 1) + 1):
			for i in range(maxi(ci - st.x, 0), mini(ci + st.x, cols - 1) + 1):
				var idx := j * cols + i
				if prev[idx] == 1:
					# favour open space, then staying put, then the preferred line
					var mv := Vector2i(i - ci, j - cj)
					var room := float(clearance(prev, idx)) if obstacles.is_empty() else _obstacle_room(near, cell_pos(idx), zs[k - 1])
					var d := float(mv.x * mv.x + mv.y * mv.y) * 1.5 + cell_pos(idx).distance_squared_to(prefer) * 0.02 - room * 6.0
					# discourage zig-zags that an acceleration-limited ship cannot follow
					if (mv.x != 0 and signi(mv.x) == -signi(last_move.x)) or (mv.y != 0 and signi(mv.y) == -signi(last_move.y)):
						d += 3.0
					if d < best_d:
						best_d = d
						best = idx
		if best >= 0:
			var m2 := Vector2i(best % cols - ci, best / cols - cj)
			if m2 != Vector2i.ZERO:
				last_move = m2
			cur = best
		cells.append(cur)
	cells.reverse()
	for k in n:
		var c := cell_pos(cells[k])
		path.append(Vector3(c.x, c.y, zs[k]))
	return path
