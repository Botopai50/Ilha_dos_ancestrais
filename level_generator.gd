extends Node3D

var plain_scenes: Array[PackedScene] = []
var mountain_scenes: Array[PackedScene] = []
var lake_scenes: Array[PackedScene] = []
var river_models_cache: Dictionary = {}

@export var grid_size_x: int = 10
@export var grid_size_z: int = 10
@export var tile_spacing: float = 100.0
var mountain_noise = FastNoiseLite.new()

var palette_material: ShaderMaterial
var water_material: ShaderMaterial
var river_cells: Dictionary = {}
var river_start_pos: Vector2i = Vector2i(4, 1)

func _ready():
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
	
	uniform sampler2D atlas_texture : source_color, filter_nearest;
	varying flat vec2 final_uv;
	
	void vertex() {
		// 1. Água do rio e lagos: preserva a textura azul cristalina nativa
		if (VERTEX.y < -0.8) {
			final_uv = UV;
		}
		// 2. Cumes altos das montanhas: cobertura de neve alpina
		else if (VERTEX.y > 15.0) {
			final_uv = vec2(0.75, 0.25);
		}
		// 3. Paredões rochosos íngremes das montanhas: rocha cinza
		else if (UV.x < 0.5 && UV.y >= 0.5 && VERTEX.y > 3.0) {
			final_uv = vec2(0.25, 0.75);
		}
		// 4. Todo o solo continental, planícies e margens: grama verde exuberante
		else {
			final_uv = vec2(0.25, 0.25);
		}
	}
	
	void fragment() {
		vec3 col = texture(atlas_texture, final_uv).rgb;
		if (final_uv.x >= 0.5 && final_uv.y < 0.5) {
			col = vec3(0.90, 0.94, 0.98); // Neve suave com relevo
		}
		ALBEDO = col;
		ROUGHNESS = 0.85;
	}
	"""
	
	palette_material = ShaderMaterial.new()
	palette_material.shader = shader
	
	var path = "res://Assets/TerrainModels/CPT_Terrain_Texture_Atlas_01.png"
	var img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img:
		var texture = ImageTexture.create_from_image(img)
		palette_material.set_shader_parameter("atlas_texture", texture)

	load_terrain_models()
	generate_island()

func load_terrain_models():
	var dir = DirAccess.open("res://Assets/TerrainModels/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".fbx"):
				# Planícies abertas e limpas
				if file_name.begins_with("CPT_Terrain_L_a_01"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						plain_scenes.append(scene)
				# Lagos alpinos fechados
				elif file_name == "MT_Terrain_L_b_02.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						lake_scenes.append(scene)
				# Montanhas e cordilheiras
				elif file_name in ["MT_Terrain_L_a_09.fbx", "MT_Terrain_L_c_18.fbx"]:
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						mountain_scenes.append(scene)
				# Modelos de Rio
				elif file_name.begins_with("CPT_River_"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_models_cache[file_name] = scene
			file_name = dir.get_next()

func solve_and_plan_river():
	river_cells.clear()
	# Escolha procedural da coluna do rio
	var cur_x = 3 + (randi() % 4)
	river_start_pos = Vector2i(cur_x, 1)
	
	# 1. Nascente ao norte (socket S@12.5)
	river_cells[Vector2i(cur_x, 1)] = {
		"file": "CPT_River_End_L_a_01.fbx",
		"rot": 0
	}
	
	# 2. Curso d'água contínuo com conexão milimétrica de vértices (N@12.8 -> S@12.5)
	for z in range(2, 9):
		river_cells[Vector2i(cur_x, z)] = {
			"file": "CPT_River_L_a_01.fbx",
			"rot": 0
		}
		
	# 3. Foz no mar ao sul (N@12.8 -> deságue suave no oceano aberto)
	river_cells[Vector2i(cur_x, 9)] = {
		"file": "CPT_River_End_L_c_01_R.fbx",
		"rot": 2
	}

func spawn_water_plane():
	var ocean = MeshInstance3D.new()
	ocean.name = "OceanWaterPlane"
	var pm = PlaneMesh.new()
	pm.size = Vector2(4000.0, 4000.0)
	ocean.mesh = pm
	var o_mat = StandardMaterial3D.new()
	o_mat.albedo_color = Color(0.10, 0.35, 0.55, 0.95)
	o_mat.roughness = 0.15
	ocean.material_override = o_mat
	ocean.position = Vector3(
		(grid_size_x * tile_spacing) / 2.0,
		-1.8,
		(grid_size_z * tile_spacing) / 2.0
	)
	add_child(ocean)

func generate_island():
	mountain_noise.seed = randi()
	mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	mountain_noise.frequency = 0.20
	
	solve_and_plan_river()
	spawn_water_plane()
	
	var river_col = river_start_pos.x
	
	# Gera todos os 100 módulos procedurais do mundo
	for x in range(grid_size_x):
		for z in range(grid_size_z):
			var pos_key = Vector2i(x, z)
			var chosen_file = "CPT_Terrain_L_a_01_LOD.fbx"
			var rot_idx = 0
			
			if river_cells.has(pos_key):
				chosen_file = river_cells[pos_key]["file"]
				rot_idx = river_cells[pos_key]["rot"]
			else:
				var dist_to_river = abs(x - river_col)
				# Campo contínuo de ruído procedural
				var n = mountain_noise.get_noise_2d(x * 2.0, z * 2.0)
				# Efeito de vale: o relevo é rebaixado nas margens do rio
				var valley_factor = clamp((dist_to_river - 1.0) / 2.5, 0.0, 1.0)
				var effective_elev = n * valley_factor
				
				if effective_elev > 0.18:
					# Cordilheiras e cumes
					if effective_elev > 0.38:
						chosen_file = "MT_Terrain_L_b_02.fbx"
						rot_idx = (x + z) % 4
					elif effective_elev > 0.28:
						chosen_file = "MT_Terrain_L_a_09.fbx"
						rot_idx = (x * 2 + z) % 4
					else:
						chosen_file = "MT_Terrain_L_c_18.fbx"
						rot_idx = (x + z * 2) % 4
				else:
					# Vales verdes e planícies costeiras
					chosen_file = "CPT_Terrain_L_a_01_LOD.fbx"
					rot_idx = 0
					
			spawn_tile_centered(x, z, chosen_file, rot_idx)
			
	var player = get_node_or_null("../Player")
	if player:
		player.position = Vector3(
			river_start_pos.x * tile_spacing + 50.0,
			25.0,
			river_start_pos.y * tile_spacing + 70.0
		)

func spawn_tile_centered(x: int, z: int, file_name: String, rot_idx: int):
	var scene: PackedScene = null
	if river_models_cache.has(file_name):
		scene = river_models_cache[file_name]
	else:
		var p = "res://Assets/TerrainModels/" + file_name
		if ResourceLoader.exists(p):
			scene = load(p)
		elif not plain_scenes.is_empty():
			scene = plain_scenes[0]
			
	if not scene:
		return
		
	# Pivô Universal Centralizado: elimina 100% dos deslocamentos e buracos entre blocos
	var container = Node3D.new()
	container.position = Vector3(x * tile_spacing + 50.0, 0, z * tile_spacing + 50.0)
	container.rotation.y = rot_idx * (PI / 2.0)
	add_child(container)
	
	var tile_instance = scene.instantiate()
	tile_instance.position = Vector3(-50.0, 0, 50.0)
	container.add_child(tile_instance)
	
	create_collisions_recursive(tile_instance)

func create_collisions_recursive(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		if palette_material:
			node.material_override = palette_material
	for child in node.get_children():
		create_collisions_recursive(child)