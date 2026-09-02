extends SceneTree
func _init():
    var img = Image.load_from_file(ProjectSettings.globalize_path('res://Assets/TerrainModels/U_Terrain_Rock_01.png'))
    if img:
        print('Size: ', img.get_size())
        for y in range(img.get_height()):
            var row = ''
            for x in range(img.get_width()):
                var c = img.get_pixel(x, y)
                row += str(c.to_html(false)) + ' '
            print(row)
    quit()
