extends SceneTree
func _init():
    var dir = DirAccess.open('res://Assets/TerrainModels/')
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        var count = 0
        while file_name != '':
            if file_name.ends_with('.fbx') and not '_LOD' in file_name and file_name.begins_with('CPT_Terrain_L_a_'):
                var scene = load('res://Assets/TerrainModels/' + file_name)
                if scene is PackedScene:
                    count += 1
            file_name = dir.get_next()
        print('FOUND: ', count)
    quit()
