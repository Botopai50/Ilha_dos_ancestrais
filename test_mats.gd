extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/CPT_Terrain_L_a_04.fbx')
    if scene:
        var inst = scene.instantiate()
        var m = inst.get_child(0)
        if m is MeshInstance3D:
            for i in range(m.mesh.get_surface_count()):
                var mat = m.mesh.surface_get_material(i)
                if mat:
                    print('MAT_NAME: ', mat.resource_name)
                else:
                    print('MAT IS NULL')
    quit()
