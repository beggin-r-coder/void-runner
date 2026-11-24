shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
// Triplanar alien rock with strata, glowing veins and a hazard rim.
// Displacement is inward only and measured in world meters, so the visual
// never pokes outside the collision volume no matter how the mesh is scaled.

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 color_a : source_color = vec3(0.45, 0.2, 0.12);
uniform vec3 color_b : source_color = vec3(0.85, 0.48, 0.28);
uniform vec3 color_c : source_color = vec3(0.2, 0.08, 0.06);
uniform float tex_scale = 0.07;
uniform float strata_scale = 1.1;
uniform float strata_strength = 0.55;
uniform float disp_amp = 0.35;
uniform vec3 vein_color : source_color = vec3(1.0, 0.25, 0.6);
uniform float vein_strength = 0.0;
uniform float vein_width = 0.018;
uniform vec3 rim_color : source_color = vec3(1.0, 0.8, 0.5);
uniform float rim_strength = 0.0;
uniform float roughness_v = 0.85;
uniform float metallic_v = 0.0;
uniform float normal_depth = 1.2;
uniform float world_space = 0.0;

varying vec3 v_pos;
varying vec3 v_nrm;

vec3 tri_weights(vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0));
	return b / (b.x + b.y + b.z + 1e-4);
}

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 mp = VERTEX * sc;
	vec3 n = normalize(NORMAL / sc);
	vec3 w = tri_weights(n);
	vec3 p = mp * tex_scale;
	float h = textureLod(noise_tex, p.zy, 0.0).r * w.x + textureLod(noise_tex, p.xz, 0.0).r * w.y + textureLod(noise_tex, p.xy, 0.0).r * w.z;
	VERTEX -= NORMAL * (h * disp_amp) / sc;
	v_pos = mix(mp, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, world_space);
	v_nrm = n;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 w = tri_weights(n);
	vec3 p = v_pos * tex_scale;
	float h = texture(noise_tex, p.zy).r * w.x + texture(noise_tex, p.xz).r * w.y + texture(noise_tex, p.xy).r * w.z;
	vec3 p2 = p * 3.7;
	float h2 = texture(noise_tex, p2.zy).r * w.x + texture(noise_tex, p2.xz).r * w.y + texture(noise_tex, p2.xy).r * w.z;
	float strata = sin((v_pos.y + h * 7.0) * strata_scale) * 0.5 + 0.5;
	vec3 col = mix(color_a, color_b, smoothstep(0.32, 0.72, h));
	col = mix(col, color_c, strata * strata_strength * smoothstep(0.25, 0.75, h2));
	col *= 0.7 + 0.55 * h2;
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
	vec3 nm = texture(normal_tex, p2.zy).rgb * w.x + texture(normal_tex, p2.xz).rgb * w.y + texture(normal_tex, p2.xy).rgb * w.z;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth;
	float vein = smoothstep(vein_width, 0.0, abs(h - 0.5)) * smoothstep(0.35, 0.6, h2);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vein_color * vein * vein_strength * 4.0 + rim_color * rim * rim_strength;
}
