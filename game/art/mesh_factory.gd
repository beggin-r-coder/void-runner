class_name MeshFactory
extends RefCounted
## Procedural meshes: no external art required for the prototype.
## All hazard meshes are unit-sized (span -1..1) and scaled per instance.


static func _commit(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Unit rounded cube with smooth, continuous normals (no cracks when the
## shader displaces along NORMAL).
static func rounded_box(subdiv: int = 10, radius: float = 0.18) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	var inner := 1.0 - radius
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var base := verts.size()
		for j in subdiv + 1:
			for i in subdiv + 1:
				var a := float(i) / subdiv * 2.0 - 1.0
				var b := float(j) / subdiv * 2.0 - 1.0
				# bias samples toward the edges for nicer rounding
				a = sign(a) * pow(absf(a), 0.7)
				b = sign(b) * pow(absf(b), 0.7)
				var q: Vector3 = n + u * a + v * b
				var c := q.clamp(Vector3(-inner, -inner, -inner), Vector3(inner, inner, inner))
				var dir := (q - c).normalized()
				verts.append(c + dir * radius)
				normals.append(dir)
				uvs.append(Vector2(float(i) / subdiv, float(j) / subdiv))
		for j in subdiv:
			for i in subdiv:
				var i0 := base + j * (subdiv + 1) + i
				var i1 := i0 + 1
				var i2 := i0 + subdiv + 1
				var i3 := i2 + 1
				_quad(indices, verts, i0, i1, i3, i2, n)
	return _commit(verts, normals, uvs, indices)


## Adds two triangles with front faces toward `outward` (Godot: clockwise front).
static func _quad(indices: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int, d: int, outward: Vector3) -> void:
	_tri(indices, verts, a, b, c, outward)
	_tri(indices, verts, a, c, d, outward)


static func _tri(indices: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> void:
	var nrm := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if nrm.dot(outward) > 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])


static func icosphere(subdiv: int) -> Dictionary:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for s in subdiv:
		var cache := {}
		var nf: Array = []
		for f in faces:
			var m := []
			for e in 3:
				var a: int = f[e]
				var b: int = f[(e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not cache.has(key):
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	return {"verts": verts, "faces": faces}


## Asteroid / boulder: radius stays within [1 - depth, 1] so it never
## exceeds its collision sphere.
static func asteroid(seed_value: int, subdiv: int = 3, depth: float = 0.16) -> ArrayMesh:
	var ico := icosphere(subdiv)
	var src: Array = ico["verts"]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.1
	noise.fractal_octaves = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stretch := Vector3(rng.randf_range(0.85, 1.0), rng.randf_range(0.75, 1.0), rng.randf_range(0.85, 1.0))
	var craters: Array = []
	for i in 6:
		craters.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.2, 0.45)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: Array[Vector3] = []
	for v in src:
		var p: Vector3 = v
		var n := noise.get_noise_3dv(p * 1.3) * 0.5 + 0.5
		var r := 1.0 - depth * n
		for c in craters:
			var dd := p.distance_to(c[0])
			if dd < c[1]:
				r -= 0.06 * (1.0 - pow(dd / c[1], 2.0))
		pos.append(p * stretch * clampf(r, 1.0 - depth - 0.06, 1.0))
	for f in ico["faces"]:
		for k in [0, 2, 1]:
			var p2: Vector3 = pos[f[k]]
			st.set_uv(Vector2(p2.x, p2.y))
			st.add_vertex(p2)
	st.index()
	st.generate_normals()
	return st.commit()


## Unit cylinder (radius 1, y -1..1) with smooth normals, no caps (caps are
## always buried in floor / walls or beyond view).
static func smooth_cylinder(segments: int = 18, rings: int = 10, capped: bool = true) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in rings + 1:
		var y := float(j) / rings * 2.0 - 1.0
		for i in segments + 1:
			var a := float(i) / segments * TAU
			var n := Vector3(cos(a), 0.0, sin(a))
			verts.append(Vector3(n.x, y, n.z))
			normals.append(n)
			uvs.append(Vector2(float(i) / segments, float(j) / rings))
	for j in rings:
		for i in segments:
			var i0 := j * (segments + 1) + i
			var i1 := i0 + 1
			var i2 := i0 + segments + 1
			var i3 := i2 + 1
			var mid := (verts[i0] + verts[i3]) * 0.5
			_quad(indices, verts, i0, i1, i3, i2, Vector3(mid.x, 0.0, mid.z))
	if capped:
		for side in [-1.0, 1.0]:
			var center := verts.size()
			verts.append(Vector3(0, side, 0))
			normals.append(Vector3(0, side, 0))
			uvs.append(Vector2(0.5, 0.5))
			var ring_start := verts.size()
			for i in segments + 1:
				var a2 := float(i) / segments * TAU
				verts.append(Vector3(cos(a2), side, sin(a2)))
				normals.append(Vector3(0, side, 0))
				uvs.append(Vector2(cos(a2), sin(a2)) * 0.5 + Vector2(0.5, 0.5))
			for i in segments:
				_tri(indices, verts, center, ring_start + i, ring_start + i + 1, Vector3(0, side, 0))
	return _commit(verts, normals, uvs, indices)


## Canyon wall facing the corridor. side = -1 (left wall, faces +x) or 1.
static func canyon_wall(seed_value: int, side: int, length: float = 130.0) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 5
	var ridge := FastNoiseLite.new()
	ridge.seed = seed_value + 99
	ridge.frequency = 0.012
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	var nz := 44
	var ny := 26
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[Vector3] = []
	for j in ny + 1:
		var y := lerpf(-10.0, 46.0, float(j) / ny)
		for i in nz + 1:
			var z := 15.0 - float(i) / nz * length
			var lean := maxf(y + 4.0, 0.0) * 0.22
			var shelf := smoothstep(14.0, 18.0, y) * 4.0
			var n := noise.get_noise_2d(y * 1.4, z) * 4.5 + ridge.get_noise_2d(y * 0.5, z) * 3.5
			var x := 14.2 + lean + shelf + absf(n) * 0.8 + n * 0.9
			grid.append(Vector3(x * side, y, z))
	for j in ny:
		for i in nz:
			var a := grid[j * (nz + 1) + i]
			var b := grid[j * (nz + 1) + i + 1]
			var c := grid[(j + 1) * (nz + 1) + i]
			var d := grid[(j + 1) * (nz + 1) + i + 1]
			_tri_st(st, a, b, d, Vector3(-side, 0, 0))
			_tri_st(st, a, d, c, Vector3(-side, 0, 0))
	st.generate_normals()
	return st.commit()


static func _tri_st(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot(outward) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


## Canyon / planet floor below the flight envelope.
static func terrain(seed_value: int, length: float = 130.0, half_width: float = 60.0, base_y: float = -8.5) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	var nx := 36
	var nz := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[Vector3] = []
	for j in nz + 1:
		var z := 15.0 - float(j) / nz * length
		for i in nx + 1:
			var x := lerpf(-half_width, half_width, float(i) / nx)
			var y := base_y + noise.get_noise_2d(x, z) * 1.6
			y = minf(y, -7.0)
			y += smoothstep(9.0, 30.0, absf(x)) * 9.0
			grid.append(Vector3(x, y, z))
	for j in nz:
		for i in nx:
			var a := grid[j * (nx + 1) + i]
			var b := grid[j * (nx + 1) + i + 1]
			var c := grid[(j + 1) * (nx + 1) + i]
			var d := grid[(j + 1) * (nx + 1) + i + 1]
			_tri_st(st, a, b, d, Vector3.UP)
			_tri_st(st, a, d, c, Vector3.UP)
	st.generate_normals()
	return st.commit()


## Tall tapered rock spire for skylines.
static func spire(seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.6
	var segs := 10
	var rings := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[Vector3] = []
	for j in rings + 1:
		var t := float(j) / rings
		var y := t * 2.0 - 1.0
		var r := lerpf(1.0, 0.18, pow(t, 0.8))
		for i in segs + 1:
			var a := float(i % segs) / segs * TAU
			var n := noise.get_noise_2d(a * 2.0, y * 3.0) * 0.25
			grid.append(Vector3(cos(a) * (r + n * r), y, sin(a) * (r + n * r)))
	for j in rings:
		for i in segs:
			var a2 := grid[j * (segs + 1) + i]
			var b := grid[j * (segs + 1) + i + 1]
			var c := grid[(j + 1) * (segs + 1) + i]
			var d := grid[(j + 1) * (segs + 1) + i + 1]
			var mid := (a2 + d) * 0.5
			_tri_st(st, a2, b, d, Vector3(mid.x, 0, mid.z))
			_tri_st(st, a2, d, c, Vector3(mid.x, 0, mid.z))
	st.generate_normals()
	return st.commit()


## Flat polygon (in XZ) extruded along Y, flat-shaded.
static func extrude(poly: PackedVector2Array, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ht := thickness * 0.5
	var tris := Geometry2D.triangulate_polygon(poly)
	for sgn in [1.0, -1.0]:
		var nrm := Vector3(0, sgn, 0)
		for i in range(0, tris.size(), 3):
			var a := Vector3(poly[tris[i]].x, ht * sgn, poly[tris[i]].y)
			var b := Vector3(poly[tris[i + 1]].x, ht * sgn, poly[tris[i + 1]].y)
			var c := Vector3(poly[tris[i + 2]].x, ht * sgn, poly[tris[i + 2]].y)
			st.set_normal(nrm)
			_tri_st(st, a, b, c, nrm)
	var centroid := Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= poly.size()
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var edge := p1 - p0
		var out2 := Vector2(edge.y, -edge.x).normalized()
		if out2.dot((p0 + p1) * 0.5 - centroid) < 0.0:
			out2 = -out2
		var nrm2 := Vector3(out2.x, 0, out2.y)
		var a3 := Vector3(p0.x, ht, p0.y)
		var b3 := Vector3(p1.x, ht, p1.y)
		var c3 := Vector3(p1.x, -ht, p1.y)
		var d3 := Vector3(p0.x, -ht, p0.y)
		st.set_normal(nrm2)
		_tri_st(st, a3, b3, c3, nrm2)
		st.set_normal(nrm2)
		_tri_st(st, a3, c3, d3, nrm2)
	return st.commit()


## Engine plume: surface of revolution along +Z (nozzle at z=0, tail at z=1),
## radius 1 at the nozzle, slight bulge just behind it, then a soft taper.
## UV.y runs 0 (nozzle) -> 1 (tail) for the flame shader.
static func plume(segments: int = 18, rings: int = 28) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in rings + 1:
		var t := float(j) / rings
		var r := (1.0 + 0.22 * sin(clampf(t * 3.2, 0.0, PI))) * pow(1.0 - t, 0.65) + 0.015
		for i in segments + 1:
			var a := float(i) / segments * TAU
			var n := Vector3(cos(a), sin(a), 0.0)
			verts.append(Vector3(n.x * r, n.y * r, t))
			normals.append(n)
			uvs.append(Vector2(float(i) / segments, t))
	for j in rings:
		for i in segments:
			var i0 := j * (segments + 1) + i
			var i1 := i0 + 1
			var i2 := i0 + segments + 1
			var i3 := i2 + 1
			var mid := (verts[i0] + verts[i3]) * 0.5
			_quad(indices, verts, i0, i1, i3, i2, Vector3(mid.x, mid.y, 0.0))
	return _commit(verts, normals, uvs, indices)


## Additive speed streak: two crossed quads along Z, UV.x along the length.
static func streak(length: float = 4.0, width: float = 0.04) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var axes := [Vector3(width, 0, 0), Vector3(0, width, 0)]
	for ax in axes:
		var base := verts.size()
		var w: Vector3 = ax
		verts.append_array([Vector3(0, 0, -length * 0.5) - w, Vector3(0, 0, -length * 0.5) + w, Vector3(0, 0, length * 0.5) + w, Vector3(0, 0, length * 0.5) - w])
		uvs.append_array([Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0)])
		for k in 4:
			normals.append(Vector3(0, 0, 1))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return _commit(verts, normals, uvs, indices)


static func noise_textures(seed_value: int) -> Array[Texture2D]:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 5
	var img := n.get_seamless_image(256, 256)
	var img_n := img.duplicate() as Image
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	img_n.convert(Image.FORMAT_RGBA8)
	img_n.bump_map_to_normal_map(6.0)
	img_n.generate_mipmaps()
	var tex_n := ImageTexture.create_from_image(img_n)
	var out: Array[Texture2D] = [tex, tex_n]
	return out
