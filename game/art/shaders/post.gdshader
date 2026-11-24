shader_type canvas_item;
// Speed post-process (High preset): radial blur at the edges, chromatic
// aberration, vignette and full-screen flashes. The centre stays sharp so
// hazards remain readable.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.0;
uniform float vignette = 0.38;
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float aberration = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.6, 1.0));
	float edge = smoothstep(0.25, 0.75, r);
	float ca = intensity * 0.007 * edge * aberration;
	vec3 col;
	col.r = texture(screen_tex, uv - c * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv + c * ca).b;
	if (intensity > 0.02) {
		vec3 acc = col;
		float blur = 0.022 * intensity * edge;
		for (int i = 1; i <= 4; i++) {
			acc += texture(screen_tex, uv - c * blur * float(i)).rgb;
		}
		col = acc / 5.0;
	}
	col *= 1.0 - vignette * smoothstep(0.3, 1.0, r);
	col = mix(col, flash_color, clamp(flash * (0.35 + r * 0.8), 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
