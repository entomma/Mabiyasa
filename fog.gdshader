shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// --------- Settings ---------

uniform sampler2D noise_tex : source_color;

uniform vec4 fog_color : source_color = vec4(0.82, 0.88, 0.92, 1.0);

uniform float opacity : hint_range(0.0, 1.0) = 0.22;
uniform float scale : hint_range(0.1, 10.0) = 3.0;
uniform float speed : hint_range(0.0, 1.0) = 0.02;

// Controls how soft the edges are.
// Higher = larger fade.
uniform float edge_fade : hint_range(0.1, 0.5) = 0.35;

// --------- Shader ---------

void fragment()
{
	// Animated UVs
	vec2 uv = UV * scale;
	uv += vec2(TIME * speed, TIME * speed * 0.25);

	// Sample noise
	float fog = texture(noise_tex, uv).r;

	// Make the noise softer
	fog = smoothstep(0.30, 0.75, fog);

	// Circular fade from center
	vec2 center = UV - vec2(0.5);
	float dist = length(center);

	float fade = 1.0 - smoothstep(edge_fade, 0.70, dist);

	// Final color
	ALBEDO = fog_color.rgb;
	ALPHA = fog * opacity * fade;
}