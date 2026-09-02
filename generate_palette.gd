extends SceneTree
func _init():
    var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
    for y in range(16):
        for x in range(16):
            var c = Color(0, 0, 0, 1)
            # Row 0-3: Snow / White
            if y < 4: c = Color(0.9, 0.9, 0.95)
            # Row 4-7: Rock / Gray
            elif y < 8: c = Color(0.5, 0.5, 0.5)
            # Row 8-11: Grass / Green
            elif y < 12: c = Color(0.2, 0.6, 0.2)
            # Row 12-15: Dirt / Sand / Brown
            else: c = Color(0.6, 0.4, 0.2)
            
            # Make columns vary lightness
            var lightness = 0.5 + (x / 16.0) * 0.5
            c = c * lightness
            c.a = 1.0
            img.set_pixel(x, y, c)
            
    img.save_png('C:/Users/juliano.silva/.gemini/antigravity/scratch/ilha_dos_ancestrais/Assets/TerrainModels/GeneratedPalette.png')
    print('Generated palette!')
    quit()
