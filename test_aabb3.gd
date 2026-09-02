extends SceneTree
func _init():
    var dir = DirAccess.open('res://Assets/TerrainModels/')
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != '':
            if file_name.ends_with('.fbx') and not '_LOD' in file_name:
                var scene = load('res://Assets/TerrainModels/' + file_name)
                if scene:
                    var inst = scene.instantiate()
                    var aabb = AABB()
                    var has_mesh = false
                    for c in inst.get_children():
                        if c is MeshInstance3D:
                            if not has_mesh:
                                aabb = c.get_aabb()
                                has_mesh = true
                            else:
                                aabb = aabb.merge(c.get_aabb())
                    if has_mesh and aabb.size.y > 5.0:
                        print(file_name, ' Y: ', aabb.size.y)
            file_name = dir.get_next()
    quit()
