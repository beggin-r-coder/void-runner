class_name GameMaterials
extends RefCounted
## Builds and caches every material, per visual theme. Hazards get a
## brighter rim than scenery so collidable things always read as hazards.

const ROCK := preload("res://game/art/shaders/rock.gdshader")
const RUIN := preload("res://game/art/shaders/ruin.gdshader")
const ENERGY := preload("res://game/art/shaders/energy.gdshader")
const TRAIL := preload("res://game/art/shaders/trail.gdshader")
const FLAME := preload("res://game/art/shaders/flame.gdshader")
const SHOCK := preload("res://game/art/shaders/shockwave.gdshader")

var noise: Texture2D
var noise_normal: Texture2D
## themes[i] = { "hazard": [BOX, SPHERE, CYL_V, CYL_H], "deco_rock", "deco_ruin", "crystal", ... }
var themes: Array[Dictionary] = []


func _init(profiles: Array) -> void:
	var tex := MeshFactory.noise_textures(7)
	noise = tex[0]
	noise_normal = tex[1]
	for i in profiles.size():
		themes.append(_build_theme(i, profiles[i]))


func rock(p: ThemeProfile, hazard: bool, veins: float, scale: float = 0.07) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROCK
	m.set_shader_parameter("noise_tex", noise)
	m.set_shader_parameter("normal_tex", noise_normal)
	m.set_shader_parameter("color_a", p.rock_a)
	m.set_shader_parameter("color_b", p.rock_b)
	m.set_shader_parameter("color_c", p.rock_c)
	m.set_shader_parameter("vein_color", p.accent)
	m.set_shader_parameter("vein_strength", veins)
	m.set_shader_parameter("tex_scale", scale)
	m.set_shader_parameter("rim_color", p.hazard_rim)
	m.set_shader_parameter("rim_strength", 0.55 if hazard else 0.0)
	m.set_shader_parameter("disp_amp", 0.35 if hazard else 0.0)
	return m


func ruin(p: ThemeProfile, hazard: bool, glow: Color, windows: float, lines: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RUIN
	m.set_shader_parameter("noise_tex", noise)
	m.set_shader_parameter("base_color", p.rock_c.lerp(Color(0.05, 0.055, 0.06), 0.5))
	m.set_shader_parameter("panel_color", p.rock_b.lerp(Color(0.16, 0.17, 0.19), 0.6))
	m.set_shader_parameter("glow_color", glow)
	m.set_shader_parameter("window_density", windows)
	m.set_shader_parameter("line_density", lines)
	m.set_shader_parameter("rim_color", p.hazard_rim)
	m.set_shader_parameter("rim_strength", 0.6 if hazard else 0.0)
	m.set_shader_parameter("glow_strength", 3.2 if hazard else 2.4)
	return m


func crystal(color: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.4)
	m.metallic = 0.3
	m.roughness = 0.08
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.rim_enabled = true
	m.rim = 0.8
	return m


func energy(color: Color, strength: float = 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ENERGY
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", strength)
	return m


func trail(color: Color, strength: float = 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TRAIL
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", strength)
	return m


func flame(outer: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAME
	m.set_shader_parameter("outer_color", outer)
	return m


func shock(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHOCK
	m.set_shader_parameter("color", color)
	return m


func _build_theme(index: int, p: ThemeProfile) -> Dictionary:
	var d := {}
	match p.dresser_kind:
		0:  # alien canyon planet
			var hz := rock(p, true, 0.35)
			d["hazard"] = [hz, rock(p, true, 0.5, 0.11), hz, hz]
			d["deco_rock"] = rock(p, false, 0.5, 0.045)
			d["deco_floor"] = rock(p, false, 0.25, 0.05)
			d["crystal"] = crystal(p.accent, 3.0)
		1:  # asteroid field
			var ast := rock(p, true, 0.8, 0.12)
			var hull := ruin(p, true, Color(1.0, 0.55, 0.2), 0.15, 0.2)
			var ice := rock(p, true, 1.0, 0.09)
			ice.set_shader_parameter("color_a", Color(0.35, 0.5, 0.62))
			ice.set_shader_parameter("color_b", Color(0.75, 0.88, 0.95))
			ice.set_shader_parameter("color_c", Color(0.15, 0.22, 0.32))
			ice.set_shader_parameter("roughness_v", 0.25)
			ice.set_shader_parameter("metallic_v", 0.2)
			d["hazard"] = [hull, ast, ice, hull]
			d["deco_rock"] = rock(p, false, 0.15, 0.05)
			d["crystal"] = crystal(p.accent, 3.5)
		_:  # abandoned megastructure
			var mono := ruin(p, true, p.accent, 0.0, 0.35)
			d["hazard"] = [mono, ruin(p, true, Color(1.0, 0.45, 0.25), 0.0, 0.5), mono, mono]
			d["deco_ruin"] = ruin(p, false, p.accent, 0.12, 0.15)
			d["deco_floor"] = ruin(p, false, p.accent, 0.0, 0.08)
			d["crystal"] = crystal(p.accent, 4.0)
	d["orb"] = energy(Color(1.0, 0.78, 0.3), 3.0)
	d["index"] = index
	return d
