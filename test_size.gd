extends SceneTree
func _init():
    var scene = load('res://Assets/TerrainModels/MT_Terrain_M_a_11.fbx')
    if scene:
        var inst = scene.instantiate()
        var m = inst.get_child(0)
        if m is MeshInstance3D:
            print('POS: ', m.mesh.get_aabb().position)
    quit()
