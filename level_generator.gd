extends Node3D

var plain_scenes: Array[PackedScene] = []
var mountain_scenes: Array[PackedScene] = []
var lake_scenes: Array[PackedScene] = []
var river_straight_scenes: Array[PackedScene] = []
var river_curve_scenes: Array[PackedScene] = []
var river_end_scenes: Array[PackedScene] = []
var river_mouth_scenes: Array[PackedScene] = []
var coast_straight_scenes: Array[PackedScene] = []
var coast_corner_scenes: Array[PackedScene] = []

@export var grid_size_x: int = 10
@export var grid_size_z: int = 10
@export var tile_spacing: float = 100.0
var mountain_noise = FastNoiseLite.new()

var palette_material: ShaderMaterial
var water_material: ShaderMaterial
var river_cells: Dictionary = {}
var lake_cells: Dictionary = {}
var plain_cells: Dictionary = {}

func _ready():
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
	
	uniform sampler2D atlas_texture : source_color, filter_nearest;
	uniform sampler2D noise_texture : repeat_enable, filter_linear;
	
	varying flat vec2 final_uv;
	
	void vertex() {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float n = textureLod(noise_texture, world_pos.xz * 0.001, 0.0).r;
		
		// Determina o bioma continental unificado para todo o chão da ilha (Grama, Areia ou Neve)
		vec2 biome_uv;
		if (n > 0.80) {
			biome_uv = vec2(0.75, 0.25); // Quadrante Neve
		} else if (n < 0.28) {
			biome_uv = vec2(0.75, 0.75); // Quadrante Areia
		} else {
			biome_uv = vec2(0.25, 0.25); // Quadrante Grama
		}
		
		// Paredões e encostas rochosas íngremes das montanhas permanecem como pedra cinza
		if (UV.x < 0.5 && UV.y >= 0.5 && VERTEX.y > 2.5) {
			if (n > 0.80) {
				biome_uv = vec2(0.75, 0.25); // Cume com neve
			} else {
				biome_uv = vec2(0.25, 0.75); // Rocha cinza
			}
		}
		
		final_uv = biome_uv;
	}
	
	void fragment() {
		vec3 col = texture(atlas_texture, final_uv).rgb;
		// Se for neve (quadrante superior direito x >= 0.5, y < 0.5), usamos um tom alpino suave (0.90, 0.94, 0.98)
		// Isso evita o estouramento puro de 1.0 e permite ver todas as sombras, facetas e relevos 3D das colinas
		if (final_uv.x >= 0.5 && final_uv.y < 0.5) {
			col = vec3(0.90, 0.94, 0.98);
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
		
	var noise_tex = NoiseTexture2D.new()
	var fnoise = FastNoiseLite.new()
	fnoise.seed = randi()
	fnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fnoise.fractal_type = FastNoiseLite.FRACTAL_NONE # Remove 100% dos harmônicos e manchas aleatórias de neve
	fnoise.frequency = 0.002 # Escala continental suave
	noise_tex.noise = fnoise
	palette_material.set_shader_parameter("noise_texture", noise_tex)
	
	# Prepara material de água low-poly
	water_material = ShaderMaterial.new()
	var w_shader = load("res://water.gdshader")
	if w_shader:
		water_material.shader = w_shader

	load_terrain_models()
	if plain_scenes.is_empty() and mountain_scenes.is_empty():
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
				# 1. Lagos alpinos fechados (apenas 1 modelo limpo e sem defeitos)
				if file_name == "MT_Terrain_L_b_02.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						lake_scenes.append(scene)
				# 2. Montanhas sólidas de pico imponente (apenas 2 modelos curados com ~20m de altura)
				elif file_name in ["MT_Terrain_L_a_09.fbx", "MT_Terrain_L_c_18.fbx"]:
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						mountain_scenes.append(scene)
				# 3. Praias e costas planas no nível do mar (apenas 1 modelo plano)
				elif file_name == "CPT_Terrain_L_a_01.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						coast_straight_scenes.append(scene)
				# 4. Planícies abertas e limpas (apenas 2 modelos planos sem relevo acidentado)
				elif file_name in ["CPT_Terrain_L_a_01.fbx", "CPT_Terrain_L_a_04.fbx"]:
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						plain_scenes.append(scene)
				# 5. River End (Nascente / final fechado dentro do mapa)
				elif file_name == "CPT_River_End_L_a_01.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_end_scenes.append(scene)
				# 6. Foz (Deságue aberto no mar com canal alinhado em X=9.375)
				elif file_name == "CPT_River_End_L_c_01_R.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_mouth_scenes.append(scene)
				# 7. Trecho reto de rio (apenas 1 modelo curado)
				elif file_name == "CPT_River_L_a_01.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_straight_scenes.append(scene)
				# 8. Curva de rio (apenas 1 modelo curado)
				elif file_name == "CPT_River_L_b_01.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_curve_scenes.append(scene)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

const DIR_NORTH = Vector2i(0, -1)
const DIR_SOUTH = Vector2i(0, 1)
const DIR_WEST  = Vector2i(-1, 0)
const DIR_EAST  = Vector2i(1, 0)

var river_start_pos: Vector2i = Vector2i(4, 1)

func generate_natural_river_path() -> Array:
	var path = []
	var river_x = 4
	river_start_pos = Vector2i(river_x, 1)
	for z in range(1, grid_size_z):
		path.append(Vector2i(river_x, z))
	return path

func solve_and_plan_river():
	river_cells.clear()
	lake_cells.clear()
	
	var path = generate_natural_river_path()
	var n = path.size()
	if n < 2:
		return
		
	for i in range(n):
		var cell = path[i]
		if i == 0:
			# 1. River End: Final / nascente fechada dentro do mapa
			var to_next = path[i + 1] - cell
			var rot = 0
			if to_next == DIR_SOUTH: rot = 0
			elif to_next == DIR_EAST:  rot = 1
			elif to_next == DIR_NORTH: rot = 2
			elif to_next == DIR_WEST:  rot = 3
			river_cells[cell] = { "type": "river_end", "rot": rot }
			
		elif i == n - 1:
			# 2. Foz: Deságue na borda do mundo
			var from_prev = path[i - 1] - cell
			var rot = 2
			if from_prev == DIR_SOUTH: rot = 0
			elif from_prev == DIR_EAST:  rot = 1
			elif from_prev == DIR_NORTH: rot = 2
			elif from_prev == DIR_WEST:  rot = 3
			river_cells[cell] = { "type": "mouth", "rot": rot }
			
		else:
			# 3. Trechos intermediários: Retas ou Curvas
			var d1 = path[i - 1] - cell
			var d2 = path[i + 1] - cell
			
			if (d1 == DIR_NORTH and d2 == DIR_SOUTH) or (d1 == DIR_SOUTH and d2 == DIR_NORTH):
				river_cells[cell] = { "type": "straight", "rot": 0 }
			elif (d1 == DIR_WEST and d2 == DIR_EAST) or (d1 == DIR_EAST and d2 == DIR_WEST):
				river_cells[cell] = { "type": "straight", "rot": 1 }
			else:
				var has_s = (d1 == DIR_SOUTH or d2 == DIR_SOUTH)
				var has_n = (d1 == DIR_NORTH or d2 == DIR_NORTH)
				var has_e = (d1 == DIR_EAST  or d2 == DIR_EAST)
				var has_w = (d1 == DIR_WEST  or d2 == DIR_WEST)
				
				var rot = 0
				if has_s and has_e: rot = 0
				elif has_n and has_e: rot = 1
				elif has_n and has_w: rot = 2
				elif has_s and has_w: rot = 3
				river_cells[cell] = { "type": "curve", "rot": rot }
				
	# 4. Planeja 1 a 2 lagos alpinos fechados em vales de montanha distantes do rio
	var candidates = [
		Vector2i(grid_size_x - 3, 3),
		Vector2i(grid_size_x - 3, 5),
		Vector2i(2, 4),
		Vector2i(2, 6)
	]
	for cand in candidates:
		var ok = true
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if river_cells.has(cand + Vector2i(dx, dz)):
					ok = false
					break
			if not ok:
				break
		if ok:
			lake_cells[cand] = { "rot": randi() % 4 }
			if lake_cells.size() >= 2:
				break

func spawn_water_plane():
	var ocean = MeshInstance3D.new()
	ocean.name = "OceanWaterPlane"
	var pm = PlaneMesh.new()
	pm.size = Vector2(3000.0, 3000.0)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
	ocean.mesh = pm
	if water_material:
		ocean.material_override = water_material
	ocean.position = Vector3(
		(grid_size_x * tile_spacing) / 2.0,
		-0.7,
		(grid_size_z * tile_spacing) / 2.0
	)
	add_child(ocean)

func generate_island():
	mountain_noise.seed = randi()
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = 0.12
	
	solve_and_plan_river()
	spawn_water_plane()
	
	# Seleciona exatamente 30% dos módulos da ilha para serem planícies limpas (30 módulos em grade 10x10)
	plain_cells.clear()
	var candidates = []
	for x in range(1, grid_size_x - 1):
		for z in range(1, grid_size_z - 1):
			var pos = Vector2i(x, z)
			if not river_cells.has(pos) and not lake_cells.has(pos):
				var val = mountain_noise.get_noise_2d(x, z)
				candidates.append({"pos": pos, "val": val})
	candidates.sort_custom(func(a, b): return a["val"] < b["val"])
	
	var target_plains = int(grid_size_x * grid_size_z * 0.30)
	for i in range(min(target_plains, candidates.size())):
		plain_cells[candidates[i]["pos"]] = true
	
	var player = get_node_or_null("../Player")
	if player:
		# Posiciona o jogador com vista panorâmica para o River End e início do curso d'água
		player.position = Vector3(
			river_start_pos.x * tile_spacing + 50.0,
			25.0,
			river_start_pos.y * tile_spacing + 70.0
		)

	# Preenche 100% das células do mapa garantindo que não falte nenhum módulo
	for x in range(grid_size_x):
		for z in range(grid_size_z):
			spawn_tile(x, z)

func spawn_tile(x: int, z: int):
	var pos_key = Vector2i(x, z)
	var chosen_scene: PackedScene = null
	var rot_idx = 0
	
	# 1. Rio Contínuo (Prioridade máxima)
	if river_cells.has(pos_key):
		var info = river_cells[pos_key]
		rot_idx = info["rot"]
		if info["type"] == "river_end" and not river_end_scenes.is_empty():
			chosen_scene = river_end_scenes[0]
		elif info["type"] == "mouth" and not river_mouth_scenes.is_empty():
			chosen_scene = river_mouth_scenes[0]
		elif info["type"] == "curve" and not river_curve_scenes.is_empty():
			chosen_scene = river_curve_scenes[0]
		elif not river_straight_scenes.is_empty():
			chosen_scene = river_straight_scenes[0]
		elif not plain_scenes.is_empty():
			chosen_scene = plain_scenes[randi() % plain_scenes.size()]
			
	# 2. Lago Alpino Fechado no Interior
	elif lake_cells.has(pos_key):
		rot_idx = lake_cells[pos_key]["rot"]
		if not lake_scenes.is_empty():
			chosen_scene = lake_scenes[randi() % lake_scenes.size()]
		elif not mountain_scenes.is_empty():
			chosen_scene = mountain_scenes[randi() % mountain_scenes.size()]
			
	# 3. Bordas e Costas da Ilha (Praias planas no nível do mar que encontram o oceano)
	elif x == 0 or x == grid_size_x - 1 or z == 0 or z == grid_size_z - 1:
		rot_idx = randi() % 4
		if not coast_straight_scenes.is_empty():
			chosen_scene = coast_straight_scenes[randi() % coast_straight_scenes.size()]
		elif not plain_scenes.is_empty():
			chosen_scene = plain_scenes[randi() % plain_scenes.size()]
			
	# 4. Interior da Ilha (Exatamente 30% Planícies e o restante Montanhas)
	else:
		rot_idx = randi() % 4
		if plain_cells.has(pos_key) and not plain_scenes.is_empty():
			chosen_scene = plain_scenes[randi() % plain_scenes.size()]
		elif not mountain_scenes.is_empty():
			chosen_scene = mountain_scenes[randi() % mountain_scenes.size()]
		
	if not chosen_scene:
		return
		
	var tile_instance = chosen_scene.instantiate()
	add_child(tile_instance)
	tile_instance.rotation.y = rot_idx * (PI / 2.0)
	
	# Compensa o pivô interno dos modelos FBX (180° nativos)
	var rot_offsets = [
		Vector3(0.0, 0, 100.0),     # 0 graus
		Vector3(100.0, 0, 100.0),   # 90 graus
		Vector3(100.0, 0, 0.0),     # 180 graus
		Vector3(0.0, 0, 0.0)        # 270 graus
	]
	tile_instance.position = Vector3(x * tile_spacing, 0, z * tile_spacing) + rot_offsets[rot_idx]
	
	create_collisions_recursive(tile_instance)

func create_collisions_recursive(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		if palette_material:
			node.material_override = palette_material
	for child in node.get_children():
		create_collisions_recursive(child)

