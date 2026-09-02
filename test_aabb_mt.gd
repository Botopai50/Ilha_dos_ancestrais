extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/MT_Terrain_L_a_09.fbx')
    if scene:
        var inst = scene.instantiate()
        var aabb = AABB()
        for c in inst.get_children():
            if c is MeshInstance3D:
                aabb = aabb.merge(c.get_aabb())
        print('MT_Terrain_L_a_09 Size: ', aabb.size)
    quit()
