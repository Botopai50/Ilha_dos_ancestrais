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

func _init():
	var existing = {}
	var dir = DirAccess.open('res://Assets/TerrainModels/')
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != '':
		if fn.begins_with('CPT_River_') and fn.ends_with('.fbx') and not '_LOD' in fn:
			existing[fn] = true
		fn = dir.get_next()
		
	var path = [
		Vector2i(4, 1),
		Vector2i(4, 2),
		Vector2i(5, 2),
		Vector2i(5, 3),
		Vector2i(4, 3),
		Vector2i(4, 4),
		Vector2i(4, 5),
		Vector2i(4, 6),
		Vector2i(4, 7),
		Vector2i(4, 8),
		Vector2i(4, 9)
	]
	
	for idx in range(path.size()):
		var in_dir = ''
		var out_dir = ''
		if idx > 0: in_dir = get_step_dir(path[idx], path[idx - 1])
		if idx < path.size() - 1: out_dir = get_step_dir(path[idx], path[idx + 1])
		var req = []
		if in_dir != '': req.append(in_dir)
		if out_dir != '': req.append(out_dir)
		req.sort()
		
		var matching = []
		for p in RiverCatalog.RIVER_CATALOG:
			if not existing.has(p['file']): continue
			var p_dirs = p['sockets'].keys()
			p_dirs.sort()
			if p_dirs == req:
				matching.append(p['file'] + ' rot=' + str(p['rot']) + ' sock=' + str(p['sockets']))
		print('Idx ', idx, ' cell ', path[idx], ' req=', req, ' matching count = ', matching.size())
		for m in matching:
			print('   ', m)
	quit()