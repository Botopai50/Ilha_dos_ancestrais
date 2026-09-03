extends SceneTree

const RiverCatalog = preload('res://river_catalog.gd')
const DIR_NORTH = Vector2i(0, -1)
const DIR_SOUTH = Vector2i(0, 1)
const DIR_WEST  = Vector2i(-1, 0)
const DIR_EAST  = Vector2i(1, 0)

func get_step_dir(from_pos: Vector2i, to_pos: Vector2i) -> String:
	var diff = to_pos - from_pos
	if diff == DIR_SOUTH: return 'S'
	if diff == DIR_NORTH: return 'N'
	if diff == DIR_EAST:  return 'E'
	if diff == DIR_WEST:  return 'W'
	return ''

func solve_river(path: Array, existing: Dictionary) -> Array:
	var n = path.size()
	return solve_sub(path, 0, '', existing)

func solve_sub(path: Array, idx: int, in_sock: String, existing: Dictionary) -> Array:
	var n = path.size()
	if idx == n: return []
	
	var in_dir = ''
	var out_dir = ''
	if idx > 0: in_dir = get_step_dir(path[idx], path[idx - 1])
	if idx < n - 1: out_dir = get_step_dir(path[idx], path[idx + 1])
	
	var req_dirs = []
	if in_dir != '': req_dirs.append(in_dir)
	if out_dir != '': req_dirs.append(out_dir)
	req_dirs.sort()
	
	var candidates = []
	for piece in RiverCatalog.RIVER_CATALOG:
		if not existing.has(piece['file']): continue
		var p_dirs = piece['sockets'].keys()
		p_dirs.sort()
		if p_dirs == req_dirs:
			if in_dir != '' and piece['sockets'][in_dir] != in_sock:
				continue
			candidates.append(piece)
			
	candidates.shuffle()
	for piece in candidates:
		if idx == n - 1:
			return [piece]
		var out_sock = piece['sockets'][out_dir]
		var sub = solve_sub(path, idx + 1, out_sock, existing)
		if sub.size() == (n - 1 - idx):
			var res = [piece]
			res.append_array(sub)
			return res
	return []

func _init():
	var existing = {}
	var dir = DirAccess.open('res://Assets/TerrainModels/')
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != '':
		if fn.begins_with('CPT_River_') and fn.ends_with('.fbx') and not '_LOD' in fn:
			existing[fn] = true
		fn = dir.get_next()
		
	# Let's test a simple natural river with 1 or 2 meanders:
	for trial in range(10):
		var path = []
		var cur = Vector2i(4, 1)
		path.append(cur)
		cur += DIR_SOUTH
		path.append(cur)
		
		# Lateral meander
		var side = DIR_EAST if randf() < 0.5 else DIR_WEST
		cur += side
		path.append(cur)
		cur += DIR_SOUTH
		path.append(cur)
		cur += -side
		path.append(cur)
		while cur.y < 9:
			cur += DIR_SOUTH
			path.append(cur)
			
		var sol = solve_river(path, existing)
		print('Trial ', trial, ': path size = ', path.size(), ' sol size = ', sol.size())
	quit()