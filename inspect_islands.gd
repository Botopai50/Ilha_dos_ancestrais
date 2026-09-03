extends SceneTree

func inspect(path: String):
	var s = load(path)
	if not s:
		print('Could not load ', path)
		return
	var inst = s.instantiate()
	var m = inst.get_child(0) as MeshInstance3D
	var aabb = m.get_aabb()
	print(path.get_file(), ': AABB pos=', aabb.position * 100.0, ' size=', aabb.size * 100.0)

func _init():
	var base = 'res://Assets/TerrainExtracted/Assets/Low Poly Modular Terrain Pack/Terrain_Assets/Meshes/Islands/CPT/NoLOD/L/'
	inspect(base + 'CPT_Island_L_a_02.fbx')
	inspect(base + 'CPT_Island_L_b_02.fbx')
	inspect(base + 'CPT_Island_L_c_01.fbx')
	inspect(base + 'CPT_Island_L_d_02.fbx')
	inspect(base + 'CPT_Island_L_e_01.fbx')
	quit()