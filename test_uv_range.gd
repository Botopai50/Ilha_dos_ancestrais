extends SceneTree
func _init():
    for file_name in ['CPT_Terrain_L_a_04.fbx', 'CPT_Terrain_L_b_14.fbx', 'CPT_Terrain_L_g_02.fbx']:
        var scene = load('res://Assets/TerrainModels/' + file_name)
        if scene:
            var inst = scene.instantiate()
            for c in inst.get_children():
                if c is MeshInstance3D:
                    var mesh = c.mesh
                    var arrays = mesh.surface_get_arrays(0)
                    var uvs = arrays[Mesh.ARRAY_TEX_UV]
                    var min_u = 1.0
                    var max_u = 0.0
                    for uv in uvs:
                        if uv.x < min_u: min_u = uv.x
                        if uv.x > max_u: max_u = uv.x
                    print(file_name, ' UV X range: ', min_u, ' to ', max_u)
    quit()
