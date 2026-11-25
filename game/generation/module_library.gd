class_name ModuleLibrary
extends RefCounted
## Authored corridor modules with bounded randomness.
## Obstacles extend past the flight envelope (|x| <= 8, |y| <= 4.5) so walls
## read as solid; the fairness validator certifies every placement.

const W := 12.5   # walls reach the canyon sides
const H := 9.0    # and run floor-to-sky

const HAZARD_NAMES := [
	# BOX, SPHERE, CYL_V, CYL_H
	["a canyon wall", "a boulder", "a rock spire", "a stone arch"],
	["a derelict hull", "an asteroid", "an ice shard", "a drifting girder"],
	["a monolith", "a sentinel orb", "an ancient column", "a fallen beam"],
]


static func definitions() -> Array[ChunkDefinition]:
	var d: Array[ChunkDefinition] = [
		ChunkDefinition.make(&"recovery", 80.0, 0.0, 0, true),
		ChunkDefinition.make(&"open", 90.0, 0.5, 0),
		ChunkDefinition.make(&"canyon_left", 100.0, 1.0, 0),
		ChunkDefinition.make(&"canyon_right", 100.0, 1.0, 0),
		ChunkDefinition.make(&"pillar_split", 100.0, 1.0, 0),
		ChunkDefinition.make(&"ring", 100.0, 1.0, 0),
		ChunkDefinition.make(&"debris_gap", 110.0, 1.0, 0),
		ChunkDefinition.make(&"beams", 100.0, 0.8, 1),
		ChunkDefinition.make(&"slalom", 120.0, 0.8, 1),
		ChunkDefinition.make(&"gauntlet", 120.0, 0.6, 2),
	]
	return d


static func hazard_name(theme: int, kind: int) -> String:
	return HAZARD_NAMES[clampi(theme, 0, 2)][kind]


static func generate(def: ChunkDefinition, rng: RandomNumberGenerator, band: int, density: float) -> Array:
	match def.id:
		&"canyon_left":
			return _canyon(rng, band, def.length, -1)
		&"canyon_right":
			return _canyon(rng, band, def.length, 1)
		&"pillar_split":
			return _pillars(rng, band, def.length)
		&"ring":
			return _rings(rng, band, def.length)
		&"debris_gap":
			return _debris(rng, band, def.length, density)
		&"beams":
			return _beams(rng, band, def.length)
		&"slalom":
			return _slalom(rng, band, def.length)
		&"gauntlet":
			return _gauntlet(rng, band, def.length, density)
		&"open":
			return _open(rng, band, def.length)
	return []


static func _canyon(rng: RandomNumberGenerator, band: int, length: float, side: int) -> Array:
	var out: Array = []
	var n := 2 + (1 if band >= 2 else 0)
	var spacing := (length - 30.0) / n
	var g := 0
	for i in n:
		var z := -15.0 - i * spacing - rng.randf_range(0.0, spacing * 0.35)
		var edge := rng.randf_range(-3.0, 1.0 + band * 0.7)
		var depth := rng.randf_range(3.0, 6.0)
		var s := side if i % 2 == 0 or band < 1 else side * (1 if rng.randf() < 0.6 else -1)
		if s < 0:
			out.append(ObstacleSpec.box_span(-W, edge, -H, H, z, depth, g))
		else:
			out.append(ObstacleSpec.box_span(-edge, W, -H, H, z, depth, g))
		g += 1
		if band >= 1 and rng.randf() < 0.45:
			# a ledge across the open side forces a vertical choice too
			var low := rng.randf() < 0.5
			var ly := rng.randf_range(-2.5, -0.5) if low else rng.randf_range(0.5, 2.5)
			var lz := z - depth * 0.5 - rng.randf_range(6.0, 10.0)
			if s < 0:
				out.append(ObstacleSpec.box_span(edge - 1.0, W, -H if low else ly, ly if low else H, lz, 2.0, g))
			else:
				out.append(ObstacleSpec.box_span(-W, -edge + 1.0, -H if low else ly, ly if low else H, lz, 2.0, g))
			g += 1
	return out


static func _pillars(rng: RandomNumberGenerator, band: int, length: float) -> Array:
	var out: Array = []
	var rows := 3 + (1 if band >= 2 else 0)
	var spacing := (length - 25.0) / rows
	var g := 0
	for r in rows:
		var z := -14.0 - r * spacing - rng.randf_range(0.0, spacing * 0.3)
		var count := 2 + (1 if band >= 1 and rng.randf() < 0.6 else 0)
		var xs: Array[float] = []
		var guard := 0
		while xs.size() < count and guard < 30:
			guard += 1
			var x := rng.randf_range(-8.5, 8.5)
			var ok := true
			for e in xs:
				if absf(e - x) < 5.0:
					ok = false
			if ok:
				xs.append(x)
		for x in xs:
			var rad := rng.randf_range(1.0, 1.6 + band * 0.2)
			out.append(ObstacleSpec.pillar(Vector3(x, 0.0, z + rng.randf_range(-3.0, 3.0)), rad, H, g))
			g += 1
	return out


static func _rings(rng: RandomNumberGenerator, band: int, length: float) -> Array:
	var out: Array = []
	var n := 2 + (1 if band >= 2 else 0)
	var spacing := (length - 30.0) / n
	for i in n:
		var z := -16.0 - i * spacing - rng.randf_range(0.0, spacing * 0.3)
		var hw := maxf(3.8 - band * 0.3, 2.9)
		var hh := maxf(3.0 - band * 0.2, 2.4)
		var hx := rng.randf_range(-8.0 + hw * 0.6, 8.0 - hw * 0.6)
		var hy := rng.randf_range(-4.5 + hh * 0.6, 4.5 - hh * 0.6)
		var d := 1.6
		# four frame pieces share one group id: a ring pays one near miss
		out.append(ObstacleSpec.box_span(-W, hx - hw, -H, H, z, d, i))
		out.append(ObstacleSpec.box_span(hx + hw, W, -H, H, z, d, i))
		out.append(ObstacleSpec.box_span(hx - hw, hx + hw, hy + hh, H, z, d, i))
		out.append(ObstacleSpec.box_span(hx - hw, hx + hw, -H, hy - hh, z, d, i))
	return out


static func _debris(rng: RandomNumberGenerator, band: int, length: float, density: float) -> Array:
	var out: Array = []
	var count := int(round((9.0 + band * 3.0) * density))
	for g in count:
		var z := rng.randf_range(-12.0, -length + 12.0)
		var r := rng.randf_range(0.9, 2.0 + band * 0.2)
		var s := ObstacleSpec.sphere(Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-5.0, 5.0), z), r, g)
		s.variant = rng.randi_range(0, 7)
		out.append(s)
	return out


static func _beams(rng: RandomNumberGenerator, band: int, length: float) -> Array:
	var out: Array = []
	var rows := 3
	var spacing := (length - 25.0) / rows
	var g := 0
	for r in rows:
		var z := -14.0 - r * spacing - rng.randf_range(0.0, spacing * 0.3)
		var y := rng.randf_range(-3.0, 3.0)
		out.append(ObstacleSpec.beam(Vector3(0.0, y, z), W, rng.randf_range(0.8, 1.2), g))
		g += 1
		if band >= 2 and rng.randf() < 0.6:
			out.append(ObstacleSpec.pillar(Vector3(rng.randf_range(-6.0, 6.0), 0.0, z - 2.0), 1.1, H, g))
			g += 1
	return out


static func _slalom(rng: RandomNumberGenerator, band: int, length: float) -> Array:
	var out: Array = []
	# Walls stay >= 30 m apart: a full side-to-side swing must fit the
	# top-speed reaction window (~0.45 s at 65 m/s). See docs/TUNING_LOG.md.
	var n := 3
	var spacing := (length - 30.0) / n
	var side := -1 if rng.randf() < 0.5 else 1
	for i in n:
		var z := -15.0 - i * spacing
		var reach := rng.randf_range(-0.5, 1.0)
		if side < 0:
			out.append(ObstacleSpec.box_span(-W, reach, -H, H, z, 3.0, i))
		else:
			out.append(ObstacleSpec.box_span(-reach, W, -H, H, z, 3.0, i))
		side = -side
	return out


static func _gauntlet(rng: RandomNumberGenerator, band: int, length: float, density: float) -> Array:
	# a ring followed by debris and a closing pillar row
	var out: Array = []
	var ring := _rings(rng, band, 50.0)
	for o in ring:
		(o as ObstacleSpec).group_id += 0
		out.append(o)
	var debris := _debris(rng, band, 50.0, density * 0.8)
	for o in debris:
		var s := o as ObstacleSpec
		s.center.z -= 50.0
		s.group_id += 10
		out.append(s)
	var pz := -length + 14.0
	var px := rng.randf_range(-4.0, 4.0)
	out.append(ObstacleSpec.pillar(Vector3(px - 5.0, 0.0, pz), 1.3, H, 100))
	out.append(ObstacleSpec.pillar(Vector3(px + 5.0, 0.0, pz), 1.3, H, 101))
	return out


static func _open(rng: RandomNumberGenerator, band: int, length: float) -> Array:
	var out: Array = []
	if band == 0:
		return out
	for g in rng.randi_range(1, 3):
		var x := rng.randf_range(4.5, 9.0) * (-1.0 if rng.randf() < 0.5 else 1.0)
		var s := ObstacleSpec.sphere(Vector3(x, rng.randf_range(-4.0, 4.0), rng.randf_range(-20.0, -length + 20.0)), rng.randf_range(0.9, 1.4), g)
		s.variant = rng.randi_range(0, 7)
		out.append(s)
	return out
