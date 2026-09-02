extends SceneTree
func _init():
    var path = "res://Assets/TerrainModels/U_Terrain_Rock_01.png"
    var img = Image.load_from_file(ProjectSettings.globalize_path(path))
    if img:
        print("IMG LOADED. SIZE: ", img.get_size())
        print("IS EMPTY: ", img.is_empty())
    else:
        print("IMG IS NULL")
    quit()
