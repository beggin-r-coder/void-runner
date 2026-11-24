shader_type sky;
// Procedural space sky: gradient + horizon haze, star field, nebula,
// a lit planet with rings, and an abandoned orbital megastructure.
// No TIME use, so the sky / radiance is not re-rendered every frame.

uniform vec3 sky_top : source_color = vec3(0.1, 0.05, 0.12);
uniform vec3 sky_horizon : source_color = vec3(1.0, 0.45, 0.22);
uniform vec3 sky_bottom : source_color = vec3(0.25, 0.08, 0.06);
uniform float horizon_glow = 1.0;
uniform float star_strength = 0.3;
uniform float nebula_strength = 0.1;
uniform vec3 nebula_a : source_color = vec3(0.5, 0.15, 0.9);
uniform vec3 nebula_b : source_color = vec3(0.1, 0.6, 0.9);
uniform vec3 planet_dir = vec3(-0.35, 0.3, -1.0);
uniform float planet_radius = 0.28;
uniform vec3 planet_color : source_color = vec3(0.85, 0.75, 0.95);
uniform vec3 planet_atmo : source_color = vec3(0.6, 0.7, 1.0);
uniform float planet_strength = 1.0;
uniform float ring_strength = 0.8;
uniform vec3 ring_color : source_color = vec3(0.9, 0.8, 0.7);
uniform float mega_strength = 0.0;
uniform vec3 mega_color : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.75, 0.5);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise3(p);
		p = p * 2.03 + vec3(1.7, 9.2, 4.1);
		a *= 0.5;
	}
	return v;
}

vec3 stars(vec3 d, float scale, float threshold) {
	vec3 p = d * scale;
	vec3 id = floor(p);
	vec3 f = fract(p) - 0.5;
	float r = hash13(id);
	if (r < threshold) {
		return vec3(0.0);
	}
	vec3 off = vec3(hash13(id + 3.1), hash13(id + 7.7), hash13(id + 1.3)) - 0.5;
	float dist = length(f - off * 0.6);
	float b = smoothstep(0.09, 0.0, dist);
	float tint = hash13(id + 11.0);
	vec3 c = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), tint);
	return c * b * (0.4 + 1.6 * pow(hash13(id + 5.0), 6.0));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;

	vec3 col = mix(sky_horizon, sky_top, smoothstep(0.0, 0.55, h));
	col = mix(col, sky_bottom, smoothstep(0.0, -0.35, h));
	col += sky_horizon * horizon_glow * exp(-abs(h) * 14.0) * 0.45;

	// stars (two layers)
	col += (stars(d, 260.0, 0.975) + stars(d, 520.0, 0.985) * 0.6) * star_strength;

	// nebula
	if (nebula_strength > 0.001) {
		float n1 = fbm(d * 2.2 + vec3(3.0, 1.0, 0.0));
		float n2 = fbm(d * 4.1 + vec3(8.0, 2.0, 5.0));
		float band = exp(-pow(dot(d, normalize(vec3(0.3, 1.0, 0.2))) * 2.2, 2.0));
		vec3 neb = nebula_a * smoothstep(0.42, 0.85, n1) + nebula_b * smoothstep(0.5, 0.9, n2) * 0.8;
		neb *= 0.35 + band;
		col += neb * nebula_strength * (0.6 + 0.4 * n2);
	}

	// sun
	vec3 L = normalize(LIGHT0_DIRECTION);
	float sd = max(dot(d, L), 0.0);
	col += sun_color * (pow(sd, 900.0) * 30.0 + pow(sd, 60.0) * 0.6 + pow(sd, 6.0) * 0.18);

	// orbital megastructure: a vast broken ring circling the planet's sky
	if (mega_strength > 0.001) {
		vec3 rn = normalize(vec3(0.25, 0.9, 0.35));
		float pl = dot(d, rn);
		float lon = atan(dot(d, normalize(cross(rn, vec3(1, 0, 0)))), dot(d, normalize(cross(rn, vec3(0, 0, 1)))));
		float broken = step(0.18, fract(lon * 2.3 + 0.13)) * step(0.06, fract(lon * 7.1));
		float body = smoothstep(0.022, 0.012, abs(pl - 0.05)) * broken;
		float trim = smoothstep(0.004, 0.0, abs(pl - 0.05 - 0.016)) * broken;
		float lights = step(0.86, fract(lon * 60.0)) * smoothstep(0.012, 0.0, abs(pl - 0.05));
		col = mix(col, col * 0.15 + vec3(0.02, 0.03, 0.04), body * mega_strength * smoothstep(-0.05, 0.05, h + 0.1));
		col += mega_color * (trim * 1.5 + lights * 2.5 * broken) * mega_strength;
		// distant ruined spires silhouetted on the horizon
		float sx = atan(d.x, -d.z) * 12.0;
		float hgt = 0.02 + 0.09 * pow(hash13(vec3(floor(sx), 2.0, 1.0)), 3.0);
		float spire = step(h, hgt) * step(-0.01, h) * step(0.25, fract(sx)) * step(fract(sx), 0.75);
		col = mix(col, sky_bottom * 0.6, spire * mega_strength * 0.85);
		float win = step(0.93, hash13(floor(vec3(sx * 6.0, h * 300.0, 0.0)))) * spire;
		col += mega_color * win * 0.8 * mega_strength;
	}

	// planet
	if (planet_strength > 0.001) {
		vec3 pd = normalize(planet_dir);
		vec3 right = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
		vec3 up = normalize(cross(right, pd));
		float s = sin(planet_radius);
		vec2 uv = vec2(dot(d, right), dot(d, up)) / s;
		float facing = dot(d, pd);
		float r2 = dot(uv, uv);

		// rings, tilted ellipse behind/in front of the disk
		float tilt = 0.32;
		mat2 rot = mat2(vec2(cos(tilt), sin(tilt)), vec2(-sin(tilt), cos(tilt)));
		vec2 ruv = rot * uv;
		float rr = length(vec2(ruv.x, ruv.y * 4.2));
		float ring_mask = smoothstep(1.35, 1.4, rr) * smoothstep(2.35, 2.25, rr);
		float ring_bands = 0.55 + 0.45 * sin(rr * 38.0) * sin(rr * 11.0 + 1.0);
		ring_bands *= smoothstep(1.75, 1.8, rr) * 0.6 + 0.4;
		vec3 ring = ring_color * ring_mask * ring_bands * ring_strength * step(0.0, facing);
		bool ring_front = ruv.y < 0.0;

		if (r2 < 1.0 && facing > 0.0) {
			float z = sqrt(1.0 - r2);
			vec3 n = normalize(right * uv.x + up * uv.y - pd * z);
			vec3 lp = normalize(right * 0.75 + up * 0.35 - pd * 0.55);
			float lit = smoothstep(-0.2, 0.75, dot(n, lp));
			float bands = fbm(vec3(uv.y * 7.0, uv.x * 1.2, 2.0)) * 0.6 + fbm(vec3(uv * 3.0, 5.0)) * 0.4;
			vec3 pc = planet_color * (0.55 + 0.6 * bands);
			vec3 surf = pc * (0.04 + lit * 1.1);
			float rim = pow(1.0 - z, 3.0);
			surf += planet_atmo * rim * (0.25 + lit * 1.2);
			float edge = smoothstep(1.0, 0.985, r2);
			col = mix(col, surf, edge * planet_strength);
			if (ring_front) {
				col += ring * (0.4 + lit * 0.8);
			}
		} else {
			// atmosphere halo
			float halo = exp(-max(sqrt(r2) - 1.0, 0.0) * 18.0) * step(0.0, facing);
			col += planet_atmo * halo * 0.35 * planet_strength;
			col += ring;
		}
	}

	COLOR = col;
}
