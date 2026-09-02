extends SceneTree
func _init():
    var path = 'res://Assets/TerrainModels/CPT_Terrain_Texture_Atlas_01.png'
    var img = Image.load_from_file(ProjectSettings.globalize_path(path))
    if img:
        print('SUCCESS: ', img.get_size())
    else:
        print('FAILED')
    quit()
