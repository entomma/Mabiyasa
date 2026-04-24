shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 water_color : source_color = vec4(0.10, 0.50, 0.80, 0.55);
uniform float move_speed = 0.35;

void vertex() {
	VERTEX.y += sin(TIME + VERTEX.x * 0.5 + VERTEX.z * 0.5) * 0.005;
}

void fragment() {
	vec3 deep = vec3(0.02, 0.18, 0.42);
	vec3 shallow = vec3(0.25, 0.72, 1.00);

	// stronger visible movement
	float flow1 = sin((UV.x * 20.0) + TIME * move_speed * 3.0);
	float flow2 = cos((UV.y * 55.0) + TIME * move_speed * 2.5);
	float flow3 = sin(((UV.x + UV.y) * 100.0) + TIME * move_speed * 2.0);

	float flow = (flow1 + flow2 + flow3) / 3.0;
	flow = flow * 0.5 + 0.5;

	ALBEDO = mix(deep, shallow, flow) * water_color.rgb;
	ALPHA = water_color.a;

	ROUGHNESS = 0.1;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}