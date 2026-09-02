extends SceneTree
func _init():
    var shader = Shader.new()
    shader.code = ""
shader_type spatial;
uniform sampler2D tex;
void vertex() {
    vec4 c = textureLod(tex, UV, 0.0);
}
""
    if shader.get_rid():
        print('SUCCESS')
    quit()
