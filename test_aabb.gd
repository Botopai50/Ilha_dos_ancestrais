extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/CPT_Terrain_L_a_04.fbx')
    if scene:
        var inst = scene.instantiate()
        var aabb = AABB()
        for c in inst.get_children():
            if c is MeshInstance3D:
                aabb = aabb.merge(c.get_aabb())
        print('AABB_a_04: ', aabb.size)
    quit()
