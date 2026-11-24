shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Ribbon / streak: UV.x = 0 at head -> 1 at tail, UV.y across.

uniform vec3 color : source_color = vec3(0.3, 0.8, 1.0);
uniform float energy = 3.0;
uniform float head_fade = 0.0;

void fragment() {
	float along = UV.x;
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float a = pow(1.0 - along, 1.6) * smoothstep(0.0, head_fade + 0.001, along);
	ALBEDO = color * energy * a * pow(across, 1.4);
}
