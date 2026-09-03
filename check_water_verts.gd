extends SceneTree

func _init():
	var s = load('res://Assets/TerrainModels/CPT_River_L_b_01.fbx')
	var inst = s.instantiate()
	var m = inst.get_child(0) as MeshInstance3D
	var mesh = m.mesh
	var arrays = mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX]
	
	# Find vertices near edges with Y < 0 (river channel floor)
	print('Vertices on CPT_River_L_b_01 near boundary with Y < 0:')
	for v in verts:
		# scaled by 100
		var pos = v * 100.0
		if pos.y < -1.0:
			if abs(pos.z) < 1.0 or abs(pos.z - 100.0) < 1.0 or abs(pos.x) < 1.0 or abs(pos.x - 100.0) < 1.0:
				print('Boundary water vertex: ', pos)
	quit()