extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/CPT_Terrain_L_a_04.fbx')
    if scene:
        var inst = scene.instantiate()
        var m = inst.get_child(0)
        if m is MeshInstance3D:
            var mesh = m.mesh
            var arrays = mesh.surface_get_arrays(0)
            if arrays[Mesh.ARRAY_TEX_UV] != null:
                print('HAS UV1! Size: ', arrays[Mesh.ARRAY_TEX_UV].size())
                print('First UVs: ', arrays[Mesh.ARRAY_TEX_UV][0], arrays[Mesh.ARRAY_TEX_UV][1])
            else:
                print('NO UV1')
            if arrays[Mesh.ARRAY_TEX_UV2] != null:
                print('HAS UV2! Size: ', arrays[Mesh.ARRAY_TEX_UV2].size())
            else:
                print('NO UV2')
    quit()
