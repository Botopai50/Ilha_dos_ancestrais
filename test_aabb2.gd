extends SceneTree
func _init():
    var dir = DirAccess.open('res://Assets/TerrainModels/')
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != '':
            if file_name.ends_with('.fbx') and not '_LOD' in file_name and file_name.begins_with('CPT_Terrain_L_a_'):
                var scene = load('res://Assets/TerrainModels/' + file_name)
                if scene:
                    var inst = scene.instantiate()
                    var aabb = AABB()
                    for c in inst.get_children():
                        if c is MeshInstance3D:
                            aabb = aabb.merge(c.get_aabb())
                    print(file_name, ' Y: ', aabb.size.y)
            file_name = dir.get_next()
    quit()
