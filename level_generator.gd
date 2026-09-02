extends Node3D

var tile_scenes: Array[PackedScene] = []
@export var grid_size_x: int = 10
@export var grid_size_z: int = 10
@export var tile_spacing: float = 100.0
@export var noise_threshold: float = 0.2

var noise = FastNoiseLite.new()

var palette_material: StandardMaterial3D

func _ready():
	# Cria o material com a textura paleta que dá as cores
	palette_material = StandardMaterial3D.new()
	var texture = load("res://Assets/TerrainModels/U_Terrain_Rock_01.png")
	if texture:
		palette_material.albedo_texture = texture
		palette_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Pra ficar bem crisp/low-poly
	
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
			if file_name.ends_with(".fbx") and not "_LOD" in file_name and file_name.begins_with("CPT_Terrain_L_"):
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
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.03
	
	var center_x = grid_size_x / 2.0
	var center_z = grid_size_z / 2.0
	var max_radius = min(center_x, center_z)
	
	# Move o jogador para o centro exato da grade gerada, um pouco acima para ele cair no chão
	var player = get_node_or_null("../Player")
	if player:
		player.position = Vector3(center_x * tile_spacing, 10.0, center_z * tile_spacing)

	for x in range(grid_size_x):
		for z in range(grid_size_z):
			var dist_x = float(x) / grid_size_x - 0.5
			var dist_z = float(z) / grid_size_z - 0.5
			var dist = sqrt(dist_x * dist_x + dist_z * dist_z) * 2.0
			var falloff = clamp(1.0 - dist, 0.0, 1.0)
			
			var noise_val = (noise.get_noise_2d(x * 10.0, z * 10.0) + 1.0) / 2.0
			var final_val = noise_val * falloff
			
			# Garante que o centro da ilha (onde o jogador nasce) sempre tenha blocos
			var center_dist = sqrt(pow(x - grid_size_x/2.0, 2) + pow(z - grid_size_z/2.0, 2))
			if final_val > 0.3 or center_dist < 3.0:
				spawn_tile(x, z)

func spawn_tile(x: int, z: int):
	var tile_index = randi() % tile_scenes.size()
	var tile_instance = tile_scenes[tile_index].instantiate()
	add_child(tile_instance)
	tile_instance.position = Vector3(x * tile_spacing, 0, z * tile_spacing)
	# var random_rot = (randi() % 4) * (PI / 2.0)
	# tile_instance.rotation.y = random_rot
	
	# Gera colisão para que o jogador não caia e aplica material
	create_collisions_recursive(tile_instance)

func create_collisions_recursive(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		if palette_material:
			node.material_override = palette_material
	for child in node.get_children():
		create_collisions_recursive(child)
