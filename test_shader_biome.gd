extends SceneTree
func _init():
    var shader = Shader.new()
    shader.code = "
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform sampler2D noise_texture : repeat_enable, filter_nearest;

varying flat vec3 poly_color;

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Amostra de ruído global
    float n = textureLod(noise_texture, world_pos.xz * 0.005, 0.0).r;
    
    // Cor original da textura do atlas
    vec4 tex_color = textureLod(atlas_texture, UV, 0.0);
    vec3 final_col = tex_color.rgb;
    
    // Lógica de biomas misturada com ruído!
    if (n > 0.6) {
        // Bioma de Neve
        final_col = mix(final_col, vec3(0.9, 0.95, 1.0), 0.85);
    } else if (n < 0.4) {
        // Bioma de Terra/Deserto
        final_col = mix(final_col, vec3(0.8, 0.6, 0.4), 0.85);
    }
    
    // Além do bioma no chão, se a montanha for alta, bota neve no topo!
    if (world_pos.y + (n * 10.0) > 22.0) {
        final_col = mix(final_col, vec3(1.0, 1.0, 1.0), 0.9);
    }
    
    poly_color = final_col;
}

void fragment() {
    ALBEDO = poly_color;
}
"
    print('RID: ', shader.get_rid())
    quit()
