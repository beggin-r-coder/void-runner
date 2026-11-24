class_name ThemeProfile
extends Resource
## A modular visual theme: sky, light, fog and hazard palette.
## Numeric fields blend smoothly between sectors.

@export var display_name: String = "SECTOR"
@export var dresser_kind: int = 0  # 0 canyon planet, 1 asteroid field, 2 abandoned megastructure

@export_group("Sky")
@export var sky_top: Color = Color(0.1, 0.05, 0.12)
@export var sky_horizon: Color = Color(1.0, 0.45, 0.22)
@export var sky_bottom: Color = Color(0.25, 0.08, 0.06)
@export var horizon_glow: float = 1.0
@export var star_strength: float = 0.3
@export var nebula_strength: float = 0.1
@export var nebula_a: Color = Color(0.5, 0.15, 0.9)
@export var nebula_b: Color = Color(0.1, 0.6, 0.9)
@export var planet_dir: Vector3 = Vector3(-0.35, 0.3, -1.0)
@export var planet_radius: float = 0.28
@export var planet_color: Color = Color(0.85, 0.75, 0.95)
@export var planet_atmo: Color = Color(0.6, 0.7, 1.0)
@export var planet_strength: float = 1.0
@export var ring_strength: float = 0.8
@export var ring_color: Color = Color(0.9, 0.8, 0.7)
@export var mega_strength: float = 0.0
@export var mega_color: Color = Color(0.2, 0.9, 1.0)

@export_group("Light")
@export var sun_color: Color = Color(1.0, 0.75, 0.5)
@export var sun_energy: float = 2.0
@export var sun_dir: Vector3 = Vector3(-0.6, -0.35, -0.7)
@export var ambient_color: Color = Color(0.55, 0.3, 0.3)
@export var ambient_energy: float = 0.7

@export_group("Atmosphere")
@export var fog_color: Color = Color(0.75, 0.32, 0.2)
@export var fog_density: float = 0.0045
@export var fog_height: float = -4.0
@export var fog_height_density: float = 0.12
@export var fog_sun_scatter: float = 0.3
@export var glow_intensity: float = 0.9
@export var exposure: float = 1.0

@export_group("Hazards & accents")
@export var rock_a: Color = Color(0.45, 0.2, 0.12)
@export var rock_b: Color = Color(0.85, 0.48, 0.28)
@export var rock_c: Color = Color(0.2, 0.08, 0.06)
@export var accent: Color = Color(1.0, 0.25, 0.6)
@export var hazard_rim: Color = Color(1.0, 0.8, 0.5)
@export var speedline_color: Color = Color(1.0, 0.85, 0.7)


## Returns a new profile with every numeric / color / vector field lerped.
static func blend(a: ThemeProfile, b: ThemeProfile, t: float) -> ThemeProfile:
	var out := a.duplicate() as ThemeProfile
	for prop in a.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = prop["name"]
		var va: Variant = a.get(n)
		var vb: Variant = b.get(n)
		match typeof(va):
			TYPE_FLOAT, TYPE_COLOR, TYPE_VECTOR3:
				out.set(n, lerp(va, vb, t))
	if t >= 0.5:
		out.display_name = b.display_name
		out.dresser_kind = b.dresser_kind
	return out
