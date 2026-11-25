shader_type spatial;
// Scenery variant: no vertex displacement, single-projection texturing.
#define NO_DISPLACEMENT
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
// Triplanar alien rock with strata, glowing veins and a hazard rim.
// Performance: one packed texture (rgb normal, a height) -> 6 fetches per pixel;
// the scenery variant (NO_DISPLACEMENT) skips vertex texture fetches entirely.
// Displacement is inward only and measured in world meters, so the visual
// never pokes outside the collision volume no matter how the mesh is scaled.

uniform sampler2D packed_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
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
#ifndef NO_DISPLACEMENT
	vec3 w = tri_weights(n);
	vec3 p = mp * tex_scale;
	float h = textureLod(packed_tex, p.zy, 0.0).a * w.x + textureLod(packed_tex, p.xz, 0.0).a * w.y + textureLod(packed_tex, p.xy, 0.0).a * w.z;
	VERTEX -= NORMAL * (h * disp_amp) / sc;
	mp = VERTEX * sc;
#endif
	v_pos = mp;
	v_nrm = n;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 p = v_pos * tex_scale;
	vec3 p2 = p * 3.7;
#ifdef NO_DISPLACEMENT
	// scenery: single dominant-axis projection (2 fetches); noisy rock hides the seams
	vec3 an = abs(n);
	vec2 uv1 = an.x > an.y && an.x > an.z ? p.zy : (an.y > an.z ? p.xz : p.xy);
	vec2 uv2 = an.x > an.y && an.x > an.z ? p2.zy : (an.y > an.z ? p2.xz : p2.xy);
	float h = texture(packed_tex, uv1).a;
	vec4 d = texture(packed_tex, uv2);
#else
	vec3 w = tri_weights(n);
	float h = texture(packed_tex, p.zy).a * w.x + texture(packed_tex, p.xz).a * w.y + texture(packed_tex, p.xy).a * w.z;
	vec4 d = texture(packed_tex, p2.zy) * w.x + texture(packed_tex, p2.xz) * w.y + texture(packed_tex, p2.xy) * w.z;
#endif
	float h2 = d.a;
	float strata = sin((v_pos.y + h * 7.0) * strata_scale) * 0.5 + 0.5;
	vec3 col = mix(color_a, color_b, smoothstep(0.32, 0.72, h));
	col = mix(col, color_c, strata * strata_strength * smoothstep(0.25, 0.75, h2));
	col *= 0.7 + 0.55 * h2;
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
	NORMAL_MAP = d.rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	float vein = smoothstep(vein_width, 0.0, abs(h - 0.5)) * smoothstep(0.35, 0.6, h2);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vein_color * vein * vein_strength * 4.0 + rim_color * rim * rim_strength;
}
