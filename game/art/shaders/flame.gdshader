shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Engine plume on a cone (UV.y = 0 at nozzle). Flickers with TIME.

uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 outer_color : source_color = vec3(0.3, 0.7, 1.0);
uniform float energy = 4.0;
uniform float throttle = 1.0;

void fragment() {
	float along = UV.y;
	float f = abs(dot(NORMAL, VIEW));
	float flick = 0.85 + 0.15 * sin(TIME * 47.0 + along * 20.0) * sin(TIME * 31.0);
	float fade = pow(1.0 - along, 1.3);
	vec3 c = mix(outer_color, core_color, pow(f, 3.0) * (1.0 - along));
	ALBEDO = c * energy * fade * f * flick * (0.4 + 0.6 * throttle);
}
