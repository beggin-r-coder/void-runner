shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
// Two-tone ship paint with panel lines, a glowing spine stripe and edge rim.
// Works in object space so the pattern rides with the ship and mirrors cleanly.

uniform vec3 top_color : source_color = vec3(0.86, 0.89, 0.93);
uniform vec3 under_color : source_color = vec3(0.08, 0.1, 0.14);
uniform vec3 accent : source_color = vec3(0.2, 0.85, 1.0);
uniform float metallic_v = 0.35;
uniform float roughness_v = 0.32;
uniform float panel = 0.6;
uniform float stripe = 1.0;
uniform float split = 0.0;
uniform float stripe_width = 0.05;
uniform float glow = 0.6;
uniform float band_pos = 0.0;     // >0: livery band across the span at |x| = band_pos (wings)
uniform float band_width = 0.1;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	float up = smoothstep(-0.3, 0.3, v_nrm.y + split);
	vec3 c = mix(under_color, top_color, up);
	// recessed panel lines: frame bands along the length + slanted seams
	float pz = abs(fract(v_pos.z * 2.4 + 0.25) - 0.5);
	float px = abs(fract(abs(v_pos.x) * 1.7 + v_pos.z * 0.55) - 0.5);
	float line = max(smoothstep(0.47, 0.5, pz), smoothstep(0.48, 0.5, px) * 0.7);
	c *= 1.0 - line * panel * 0.55;
	// spine racing stripe (top only) with a thin dark keyline either side
	float ax = abs(v_pos.x);
	float sp = smoothstep(stripe_width, stripe_width * 0.6, ax) * up * stripe;
	float key = smoothstep(stripe_width * 1.6, stripe_width * 1.3, ax) * (1.0 - sp) * up * stripe;
	c = mix(c, c * 0.25, key);
	c = mix(c, accent * 0.85, sp);
	// wing livery chevron: a band across the span, slanted with the sweep
	float band = 0.0;
	if (band_pos > 0.0) {
		float bx = abs(abs(v_pos.x) - band_pos - v_pos.z * 0.35);
		band = smoothstep(band_width, band_width * 0.7, bx);
		float edge_k = smoothstep(band_width * 1.45, band_width * 1.2, bx) * (1.0 - band);
		c = mix(c, c * 0.2, edge_k);
		c = mix(c, accent * 0.9, band);
	}
	ALBEDO = c;
	METALLIC = metallic_v;
	ROUGHNESS = clamp(roughness_v + line * 0.25, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = accent * (sp + band * 0.6) * glow + top_color * rim * 0.12 * up;
}
