shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
// Abandoned-civilization panelling: weathered metal plates, dead seams,
// a few still-powered circuit lines and lit windows.

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 base_color : source_color = vec3(0.07, 0.08, 0.09);
uniform vec3 panel_color : source_color = vec3(0.15, 0.16, 0.18);
uniform vec3 glow_color : source_color = vec3(0.2, 0.95, 1.0);
uniform float glow_strength = 3.0;
uniform float panel_size = 2.0;
uniform float line_density = 0.25;
uniform float window_density = 0.0;
uniform float band_strength = 0.6;
uniform vec3 rim_color : source_color = vec3(0.35, 1.0, 0.95);
uniform float rim_strength = 0.0;
uniform float metallic_v = 0.65;
uniform float roughness_v = 0.42;

varying vec3 v_pos;
varying vec3 v_nrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_pos = VERTEX * sc + MODEL_MATRIX[3].xyz * vec3(1.0, 1.0, 0.0);
	v_nrm = normalize(NORMAL / sc);
}

void fragment() {
	vec3 n = abs(normalize(v_nrm));
	vec2 uv;
	if (n.x > n.y && n.x > n.z) {
		uv = v_pos.zy;
	} else if (n.y > n.z) {
		uv = v_pos.xz;
	} else {
		uv = v_pos.xy;
	}
	vec2 g = uv / panel_size;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = smoothstep(0.035, 0.0, e);
	float rnd = hash12(cell);
	float grime = texture(noise_tex, uv * 0.05).r;
	float grime2 = texture(noise_tex, uv * 0.21 + 0.3).r;
	vec3 col = mix(base_color, panel_color, rnd * 0.8 + 0.2);
	col *= 0.55 + 0.7 * grime;
	col = mix(col, base_color * 0.4, seam * 0.8);
	ALBEDO = col;
	METALLIC = metallic_v;
	ROUGHNESS = clamp(roughness_v + grime2 * 0.4 - 0.2, 0.05, 1.0);

	float pulse = 0.65 + 0.35 * sin(TIME * 1.7 + rnd * 6.28);
	float lit = step(1.0 - line_density, hash12(cell + 17.0));
	float circuit = seam * lit * pulse;
	// long horizontal power bands
	float band = smoothstep(0.06, 0.0, abs(fract(v_pos.y / (panel_size * 3.0)) - 0.5) - 0.01) * step(0.55, hash12(vec2(floor(v_pos.y / (panel_size * 3.0)), 3.0)));
	// windows
	vec2 wf = fract(g * vec2(3.0, 2.0));
	float win = step(0.2, wf.x) * step(wf.x, 0.8) * step(0.25, wf.y) * step(wf.y, 0.75);
	win *= step(1.0 - window_density, hash12(floor(g * vec2(3.0, 2.0)) + 5.0));
	vec3 wcol = mix(glow_color, vec3(1.0, 0.7, 0.35), step(0.7, hash12(floor(g * vec2(3.0, 2.0)) + 9.0)));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_color * (circuit + band * band_strength * pulse) * glow_strength + wcol * win * glow_strength * 0.6 + rim_color * rim * rim_strength;
}
