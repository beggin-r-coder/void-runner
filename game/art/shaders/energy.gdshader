shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// Energy pickups and accents: fresnel core, gentle pulse, HDR for bloom.

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.3);
uniform float energy = 3.0;
uniform float pulse_speed = 6.0;

void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.6);
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	ALBEDO = color * energy * (0.35 + f * 1.8) * pulse;
}
