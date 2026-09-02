extends Node3D

var grass_scenes: Array[PackedScene] = []
var snow_scenes: Array[PackedScene] = []
var mountain_scenes: Array[PackedScene] = []

@export var grid_size_x: int = 10
@export var grid_size_z: int = 10
@export var tile_spacing: float = 100.0

var island_noise = FastNoiseLite.new()
var biome_noise = FastNoiseLite.new()
var mountain_noise = FastNoiseLite.new()

var palette_material: StandardMaterial3D

func _ready():
	# Carrega a paleta de cores original do asset pack sem nenhum shader
	palette_material = StandardMaterial3D.new()
	var path = "res://Assets/TerrainModels/CPT_Terrain_Texture_Atlas_01.png"
	var img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img:
		var texture = ImageTexture.create_from_image(img)
		palette_material.albedo_texture = texture
		palette_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	load_terrain_models()
	if grass_scenes.is_empty() and snow_scenes.is_empty() and mountain_scenes.is_empty():
		print("Warning: No terrain scenes found in Assets/TerrainModels.")
		return
		
	generate_island()

func load_terrain_models():
	var dir = DirAccess.open("res://Assets/TerrainModels/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".fbx") and not "_LOD" in file_name:
				# CPT_Terrain_L_a_ são as planícies brancas de neve originais do pacote
				if file_name.begins_with("CPT_Terrain_L_a_"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						snow_scenes.append(scene)
				# As outras letras CPT (b, c, d, e, f, g) são as planícies e colinas de grama verde
				elif file_name.begins_with("CPT_Terrain_L_"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						grass_scenes.append(scene)
				# MT_Terrain_L_ são todas as montanhas com relevo escarpado
				elif file_name.begins_with("MT_Terrain_L_"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						mountain_scenes.append(scene)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

func generate_island():
	# Ruído para a forma geral da ilha
	island_noise.seed = randi()
	island_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	island_noise.frequency = 0.03
	
	# Ruído suave para distribuir grandes áreas de biomas
	biome_noise.seed = randi()
	biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	biome_noise.frequency = 0.08
	
	# Ruído para agrupar as montanhas em cordilheiras
	mountain_noise.seed = randi()
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = 0.12
	
	var center_x = grid_size_x / 2.0
	var center_z = grid_size_z / 2.0
	
	# Move o jogador para o centro da ilha
	var player = get_node_or_null("../Player")
	if player:
		player.position = Vector3(center_x * tile_spacing, 25.0, center_z * tile_spacing)

	for x in range(grid_size_x):
		for z in range(grid_size_z):
			var dist_x = float(x) / grid_size_x - 0.5
			var dist_z = float(z) / grid_size_z - 0.5
			var dist = sqrt(dist_x * dist_x + dist_z * dist_z) * 2.0
			var falloff = clamp(1.0 - dist, 0.0, 1.0)
			
			var noise_val = (island_noise.get_noise_2d(x * 10.0, z * 10.0) + 1.0) / 2.0
			var final_val = noise_val * falloff
			
			var center_dist = sqrt(pow(x - center_x, 2) + pow(z - center_z, 2))
			if final_val > 0.25 or center_dist < 2.5:
				spawn_tile(x, z)

func spawn_tile(x: int, z: int):
	var mnt_val = mountain_noise.get_noise_2d(x * 5.0, z * 5.0)
	var bio_val = biome_noise.get_noise_2d(x * 5.0, z * 5.0)
	
	var chosen_scene: PackedScene = null
	
	# Cadeias de montanhas onde o ruído de relevo é alto
	if mnt_val > 0.15 and not mountain_scenes.is_empty():
		chosen_scene = mountain_scenes[randi() % mountain_scenes.size()]
	# Grandes áreas de neve onde o ruído de bioma é alto
	elif bio_val > 0.25 and not snow_scenes.is_empty():
		chosen_scene = snow_scenes[randi() % snow_scenes.size()]
	# Grandes áreas de grama nos demais locais (bioma predominante da ilha)
	elif not grass_scenes.is_empty():
		chosen_scene = grass_scenes[randi() % grass_scenes.size()]
	elif not mountain_scenes.is_empty():
		chosen_scene = mountain_scenes[randi() % mountain_scenes.size()]
		
	if not chosen_scene:
		return
		
	var tile_instance = chosen_scene.instantiate()
	add_child(tile_instance)
	tile_instance.position = Vector3(x * tile_spacing, 0, z * tile_spacing)
	
	# Rotação modular (0, 90, 180, 270 graus) para dar variedade visual
	var random_rot = (randi() % 4) * (PI / 2.0)
	tile_instance.rotation.y = random_rot
	
	create_collisions_recursive(tile_instance)

func create_collisions_recursive(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		if palette_material:
			node.material_override = palette_material
	for child in node.get_children():
		create_collisions_recursive(child)

