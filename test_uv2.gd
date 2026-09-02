extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/CPT_Terrain_L_a_04.fbx')
    if scene:
        var inst = scene.instantiate()
        var m = inst.get_child(0)
        var mesh = m.mesh
        var arrays = mesh.surface_get_arrays(0)
        var uvs = arrays[Mesh.ARRAY_TEX_UV]
        
        var unique_uvs = []
        for uv in uvs:
            var found = false
            for u in unique_uvs:
                if uv.distance_to(u) < 0.01:
                    found = true
                    break
            if not found:
                unique_uvs.append(uv)
        
        print('UNIQUE UVS:')
        for uv in unique_uvs:
            print(uv)
    quit()
