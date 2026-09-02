extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/CPT_Terrain_L_a_04.fbx')
    if scene:
        var inst = scene.instantiate()
        var m = inst.get_child(0)
        if m is MeshInstance3D:
            var mesh = m.mesh
            var arrays = mesh.surface_get_arrays(0)
            if arrays[Mesh.ARRAY_COLOR] != null:
                print('HAS VERTEX COLORS!')
                print('Array size: ', arrays[Mesh.ARRAY_COLOR].size())
            else:
                print('NO VERTEX COLORS')
    quit()
