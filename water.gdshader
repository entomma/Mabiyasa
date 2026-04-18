shader_type spatial;
render_mode cull_disabled, blend_mix;

uniform vec4 water_color : source_color = vec4(0.1,0.5,0.8,0.8);
uniform float wave_height = 0.15;
uniform float wave_speed = 1.5;
uniform float pixel_size = 0.5;

void vertex() {
    float px = floor(VERTEX.x / pixel_size) * pixel_size;
    float pz = floor(VERTEX.z / pixel_size) * pixel_size;

    VERTEX.y += sin(px * 2.0 + TIME * wave_speed) * wave_height;
    VERTEX.y += cos(pz * 2.0 + TIME * wave_speed) * wave_height;
}

void fragment() {

    vec3 shallow = vec3(0.2,0.7,1.0);
    vec3 deep = vec3(0.0,0.3,0.7);

    float wave = sin(UV.x * 10.0 + TIME) * 0.5 + 0.5;

    ALBEDO = mix(deep, shallow, wave);
    ALPHA = 0.8;
    ROUGHNESS = 0.1;
}