shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.12, 0.52, 0.78, 0.82);
uniform vec4 deep_water_color : source_color = vec4(0.06, 0.28, 0.52, 0.95);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 0.95);
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float wave_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wave_frequency : hint_range(0.01, 1.0) = 0.08;
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.18;

uniform sampler2D depth_texture : hint_depth_texture;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * wave_frequency + TIME * wave_speed) * 
	          cos(world_pos.z * wave_frequency + TIME * wave_speed * 0.8);
	VERTEX.y += w * wave_amplitude;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	float water_depth = linear_depth - (-VERTEX.z);
	
	vec4 col = mix(water_color, deep_water_color, clamp(water_depth * 0.3, 0.0, 1.0));
	
	if (water_depth < 0.45 && water_depth > 0.0) {
		col = mix(foam_color, col, water_depth / 0.45);
	}
	
	ALBEDO = col.rgb;
	ALPHA = col.a;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.6;
}
