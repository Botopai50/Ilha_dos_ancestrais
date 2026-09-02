extends SceneTree
func _init():
    var path = 'C:/Users/juliano.silva/.gemini/antigravity/scratch/ilha_dos_ancestrais/Assets/TerrainModels/CPT_Terrain_Texture_Atlas_01.psd'
    var img = Image.load_from_file(path)
    if img:
        print('SUCCESS: ', img.get_size())
    else:
        print('FAILED TO LOAD PSD')
    quit()
