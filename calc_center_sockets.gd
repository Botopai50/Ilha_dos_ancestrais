extends SceneTree

func get_sockets_with_center_pivot(fn: String, rot_idx: int):
	var s = load('res://Assets/TerrainModels/' + fn)
	if not s: return {}
	var inst = s.instantiate()
	var m = inst.get_child(0) as MeshInstance3D
	var verts = m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	
	var rot_rad = rot_idx * (PI / 2.0)
	var edges = { 'N': [], 'S': [], 'E': [], 'W': [] }
	
	for v in verts:
		if v.y < -0.8: # Water vertex
			# Local in container
			var p_cont = v + Vector3(50.0, 0, -50.0)
			# Rotated in container
			var p_rot = p_cont.rotated(Vector3.UP, rot_rad)
			# World in cell [0, 100] x [0, 100]
			var p = p_rot + Vector3(50.0, 0, 50.0)
			
			if abs(p.z - 0.0) < 1.0: edges['N'].append(p.x)
			elif abs(p.z - 100.0) < 1.0: edges['S'].append(p.x)
			if abs(p.x - 0.0) < 1.0: edges['W'].append(p.z)
			elif abs(p.x - 100.0) < 1.0: edges['E'].append(p.z)
			
	var socks = {}
	for e in ['N', 'S', 'E', 'W']:
		if not edges[e].is_empty():
			var avg = 0.0
			for val in edges[e]: avg += val
			avg /= edges[e].size()
			socks[e] = round(avg * 10.0) / 10.0
	return socks

func _init():
	var models = [
		'CPT_River_End_L_a_01.fbx',
		'CPT_River_End_L_c_01_R.fbx',
		'CPT_River_L_a_01.fbx',
		'CPT_River_L_c_02_R.fbx',
		'CPT_River_L_b_01.fbx'
	]
	for fn in models:
		print('=== ', fn, ' ===')
		for r in range(4):
			var s = get_sockets_with_center_pivot(fn, r)
			print('  rot ', r, ' (', r*90, '°) -> ', s)
	quit()