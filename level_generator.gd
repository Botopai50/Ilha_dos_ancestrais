extends Node3D

var tile_scenes: Array[PackedScene] = []
@export var grid_size_x: int = 10
@export var grid_size_z: int = 10
@export var tile_spacing: float = 4.0
@export var noise_threshold: float = 0.2

var noise = FastNoiseLite.new()

func _ready():
	load_terrain_models()
	if tile_scenes.is_empty():
		print("Warning: No tile scenes found in Assets/TerrainModels.")
		return
		
	generate_island()

func load_terrain_models():
	var dir = DirAccess.open("res://Assets/TerrainModels/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".fbx") and not "_LOD" in file_name and ("MT_Terrain_M_a" in file_name or "MT_Terrain_M_b" in file_name):
				var scene = load("res://Assets/TerrainModels/" + file_name)
				if scene is PackedScene:
					tile_scenes.append(scene)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
		
	# FALLBACK: Se o Godot falhar em carregar os FBX (falta de importação), cria um bloco básico
	if tile_scenes.is_empty():
		print("FBX files not imported yet. Generating a fallback BoxMesh tile...")
		var fallback_scene = PackedScene.new()
		var mesh_instance = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(4, 2, 4)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.6, 0.2) # Verde mato
		box.material = mat
		mesh_instance.mesh = box
		
		var col_body = StaticBody3D.new()
		var col_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(4, 2, 4)
		col_shape.shape = box_shape
		col_body.add_child(col_shape)
		mesh_instance.add_child(col_body)
		
		# Ajusta a origem para o topo do bloco
		mesh_instance.position.y = -1.0
		
		var root = Node3D.new()
		root.add_child(mesh_instance)
		
		# Propriedade owner é necessária para o PackedScene funcionar
		mesh_instance.owner = root
		col_body.owner = root
		col_shape.owner = root
		
		fallback_scene.pack(root)
		tile_scenes.append(fallback_scene)

func generate_island():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	var center_x = grid_size_x / 2.0
	var center_z = grid_size_z / 2.0
	var max_radius = min(center_x, center_z)

	for x in range(grid_size_x):
		for z in range(grid_size_z):
			var distance_to_center = Vector2(x - center_x, z - center_z).length()
			var falloff = distance_to_center / max_radius
			var noise_val = noise.get_noise_2d(x * 10, z * 10)
			var final_val = noise_val - (falloff * falloff * 1.5)
			
			if final_val > -noise_threshold:
				spawn_tile(x, z)

func spawn_tile(x: int, z: int):
	var tile_index = randi() % tile_scenes.size()
	var tile_instance = tile_scenes[tile_index].instantiate()
	add_child(tile_instance)
	tile_instance.position = Vector3(x * tile_spacing, 0, z * tile_spacing)
	var random_rot = (randi() % 4) * (PI / 2.0)
	tile_instance.rotation.y = random_rot
