extends SceneTree
func _init():
    var shader = Shader.new()
    shader.code = "shader_type spatial; uniform sampler2D t; void vertex() { vec4 c = textureLod(t, UV, 0.0); }"
    print('RID: ', shader.get_rid())
    quit()
