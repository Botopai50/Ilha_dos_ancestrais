extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/MT_Terrain_L_a_09.fbx')
    if scene:
        var inst = scene.instantiate()
        for c in inst.get_children():
            if c is MeshInstance3D:
                var mesh = c.mesh
                var arrays = mesh.surface_get_arrays(0)
                var uvs = arrays[Mesh.ARRAY_TEX_UV]
                var min_u = 1.0; var max_u = 0.0
                var min_v = 1.0; var max_v = 0.0
                for uv in uvs:
                    if uv.x < min_u: min_u = uv.x
                    if uv.x > max_u: max_u = uv.x
                    if uv.y < min_v: min_v = uv.y
                    if uv.y > max_v: max_v = uv.y
                print('MT_Terrain_L_a_09 UV Range:')
                print('X: ', min_u, ' to ', max_u)
                print('Y: ', min_v, ' to ', max_v)
    quit()
