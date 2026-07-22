shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

uniform float pixel_size = 0.18;
uniform float move_speed = 0.35;
uniform float wave_height = 0.006;
uniform float brightness = 1.25;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	VERTEX.y +=
		sin(VERTEX.x * 0.9 + TIME * 1.0) *
		cos(VERTEX.z * 0.8 + TIME * 0.9) *
		wave_height;
}

void fragment() {

	vec2 p = floor(world_pos.xz / pixel_size);

	float t = floor(TIME * 8.0) / 8.0;

	//--------------------------------------------------
	// VERY LARGE WAVES
	//--------------------------------------------------

	float wave =
		sin(
			p.y * 0.010 +
			t * move_speed * 1.8
		);

	// Gentle horizontal distortion
	wave +=
		sin(
			p.x * 0.07 +
			t * move_speed * 0.9
		) * 0.10;

	// Tiny diagonal distortion
	wave +=
		sin(
			p.x * 0.020 +
			p.y * 0.5 +
			t * move_speed * 0.5
		) * 0.04;

	wave = wave * 0.5 + 0.5;
	wave = clamp(wave, 0.2, 1.0);

	//--------------------------------------------------
	// 5 Pixel Levels
	//--------------------------------------------------

	float level = floor(wave * 5.0) / 5.0;

	vec3 color;

	if(level < 0.20)
		color = vec3(0.10,0.18,0.36);
	else if(level < 0.40)
		color = vec3(0.14,0.28,0.46);
	else if(level < 0.60)
		color = vec3(0.20,0.40,0.58);
	else if(level < 0.80)
		color = vec3(0.32,0.56,0.72);
	else
		color = vec3(0.62,0.75,0.86);

	//--------------------------------------------------
	// VERY RARE CRESTS
	//--------------------------------------------------

	float crest =
		abs(
			fract(
				p.y * 0.008 +
				sin(p.x * 0.008) * 0.08 +
				t * 0.16
			) - 0.5
		);

	if (crest < 0.0025)
		color = mix(color, vec3(0.92,0.96,1.0), 0.55);

	//--------------------------------------------------
	// EXTREMELY RARE SPARKLE
	//--------------------------------------------------

	float sparkle = step(
		0.9995,
		fract(
			sin(dot(floor(p / 20.0), vec2(17.1,31.7))) *
			43758.5453 +
			t
		)
	);

	color += sparkle * 0.5;

	ALBEDO = color;
	EMISSION = color * brightness;

	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	ALPHA = .9;
}