shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.6, 0.3);
uniform float energy = 3.0;
uniform float fade = 1.0;

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	ALBEDO = color * energy * rim * fade;
}
