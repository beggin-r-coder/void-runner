shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Fluid engine plume on MeshFactory.plume() (axis +Z, UV.y = 0 at nozzle -> 1 at tail).
// Turbulence streams back along the plume, the body undulates in travelling
// waves and breathes, the tail lags with the ship's motion (bend), and faint
// shock diamonds pulse near the nozzle. Two layers: core + soft heat sheath.

uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 outer_color : source_color = vec3(0.3, 0.7, 1.0);
uniform float energy = 4.0;
uniform float throttle = 1.0;       // smoothed 0..~1.6 (surges above 1)
uniform vec2 bend = vec2(0.0);      // tail offset in metres (ship-local x, y)
uniform float flow_speed = 7.0;     // how fast turbulence streams backwards
uniform float wobble = 0.05;        // undulation amplitude (metres, grows to the tail)
uniform float seed = 0.0;
uniform float sheath = 0.0;         // 1 = outer heat sheath layer
uniform float radius_scale = 0.17;  // node radius scale: converts metres to mesh units

varying float v_t;
varying vec3 v_p;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.07 + 3.1) * 0.3 + vnoise(p * 4.13 + 7.7) * 0.15;
}

void vertex() {
	float t = UV.y;
	v_t = t;
	float time = TIME + seed * 13.0;
	// breathing radius (two incommensurate rates -> never looks looped)
	float breathe = 1.0 + 0.07 * sin(time * 19.0 + t * 9.0) + 0.04 * sin(time * 31.0 - t * 5.0);
	VERTEX.xy *= breathe;
	// travelling undulation, stronger toward the tail
	float tt = t * t;
	vec2 wob = vec2(sin(t * 8.0 - time * 13.0), cos(t * 6.5 - time * 10.0 + 1.3)) * wobble * tt * (1.0 + sheath);
	// tail lags behind the ship's lateral motion
	VERTEX.xy += (wob + bend * tt) / radius_scale;
	v_p = VERTEX;
}

void fragment() {
	float t = v_t;
	float facing = abs(dot(NORMAL, VIEW));
	float time = TIME + seed * 13.0;
	// turbulence advected backwards along the plume
	// stretched along the flow -> streaks that stream backwards
	vec3 q = vec3(v_p.xy * (4.5 - sheath * 2.0), t * 2.6 - time * flow_speed * 0.55 * (1.0 - sheath * 0.45));
	float n = fbm(q);
	float n2 = fbm(q * 1.9 + vec3(0.0, 0.0, -time * 2.0));
	float fade = pow(clamp(1.0 - t, 0.0, 1.0), 1.35 + sheath);
	float nozzle_soft = smoothstep(0.0, 0.06, t);
	float body = pow(facing, 1.4) * fade;
	float core = pow(facing, 3.2) * pow(clamp(1.0 - t * 1.7, 0.0, 1.0), 1.5);
	// ragged, flowing silhouette: noise eats the edges and the tail
	float edge = smoothstep(0.15, 0.65, facing + (n - 0.5) * 0.7 - t * 0.35);
	// shock diamonds near the nozzle
	float diamonds = pow(0.5 + 0.5 * cos(t * 34.0 - time * 3.0), 8.0) * clamp(1.0 - t * 2.2, 0.0, 1.0) * (1.0 - sheath);
	// colour gradient: white-hot at the nozzle -> livery colour -> dark tail
	vec3 hot = mix(core_color, outer_color, smoothstep(0.0, 0.4, t));
	float streak = smoothstep(0.25, 0.85, n);
	vec3 col = mix(outer_color * 0.6, hot, 1.0 - t) * body * edge * (0.25 + 1.1 * streak) * (1.0 - sheath * 0.35);
	col += core_color * core * (0.6 + 0.6 * n2) * (1.0 - sheath);
	col += core_color * diamonds * 0.6 * facing;
	float th = clamp(throttle, 0.0, 2.0);
	ALBEDO = col * energy * nozzle_soft * (0.35 + 0.65 * th) * (sheath > 0.5 ? 0.32 : 1.0);
}
