extends SceneTree
func _init():
    var dir = DirAccess.open('res://Assets/TerrainModels/')
    var count = 0
    if dir:
        dir.list_dir_begin()
        var fn = dir.get_next()
        while fn != '':
            if fn.ends_with('.fbx') and not '_LOD' in fn and ('MT_Terrain_M_a' in fn):
                var s = load('res://Assets/TerrainModels/' + fn)
                if s is PackedScene:
                    count += 1
            fn = dir.get_next()
    print('SUCCESS_LOADED:', count)
    quit()
