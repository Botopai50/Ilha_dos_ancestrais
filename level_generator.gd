extends Node3D

var grass_scenes: Array[PackedScene] = []
var mountain_scenes: Array[PackedScene] = []
var river_straight_scenes: Array[PackedScene] = []
var river_curve_scenes: Array[PackedScene] = []
var river_end_scenes: Array[PackedScene] = []
var river_mouth_scenes: Array[PackedScene] = []

@export var grid_size_x: int = 10
@export var grid_size_z: int = 10
@export var tile_spacing: float = 100.0
var mountain_noise = FastNoiseLite.new()

var palette_material: ShaderMaterial
var water_material: ShaderMaterial
var river_cells: Dictionary = {}

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
	if grass_scenes.is_empty() and mountain_scenes.is_empty():
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
				# 1. Montanhas escarpadas
				if file_name.begins_with("MT_Terrain_L_"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						mountain_scenes.append(scene)
				# 2. Planícies e colinas de terra/grama
				elif file_name.begins_with("CPT_Terrain_L_") and not file_name.begins_with("CPT_Terrain_L_a_") and not file_name.begins_with("CPT_Terrain_L_g_02"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						grass_scenes.append(scene)
				# 3. River End (Nascente / final fechado dentro do mapa)
				elif file_name == "CPT_River_End_L_a_01.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_end_scenes.append(scene)
				# 4. Foz (Deságue aberto no mar na borda do mundo)
				elif file_name == "CPT_River_End_L_c_02.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_mouth_scenes.append(scene)
				# 5. Trechos retos de rio
				elif file_name == "CPT_River_L_a_01.fbx" or file_name == "CPT_River_L_a_03.fbx":
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						river_straight_scenes.append(scene)
				# 6. Curvas de rio de 90 graus
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
	# River End nasce no interior alto do mapa (longe das bordas)
	var start_x = randi_range(3, grid_size_x - 4)
	var start_z = 1
	var cur = Vector2i(start_x, start_z)
	path.append(cur)
	river_start_pos = cur
	
	var visited = {cur: true}
	
	# Caminha organicamente serpenteando em direção à borda sul do mundo (Z = grid_size_z - 1)
	while cur.y < grid_size_z - 1:
		var possible = []
		var south = cur + DIR_SOUTH
		if not visited.has(south):
			possible.append(DIR_SOUTH)
			possible.append(DIR_SOUTH) # peso para descer rumo ao mar
			
		if cur.x > 2:
			var west = cur + DIR_WEST
			if not visited.has(west):
				possible.append(DIR_WEST)
		if cur.x < grid_size_x - 3:
			var east = cur + DIR_EAST
			if not visited.has(east):
				possible.append(DIR_EAST)
				
		if possible.is_empty():
			cur = cur + DIR_SOUTH
			path.append(cur)
			break
			
		var step = possible[randi() % possible.size()]
		cur = cur + step
		path.append(cur)
		visited[cur] = true
		
	return path

func solve_and_plan_river():
	river_cells.clear()
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
	mountain_noise.frequency = 0.08
	
	solve_and_plan_river()
	spawn_water_plane()
	
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
		elif not grass_scenes.is_empty():
			chosen_scene = grass_scenes[randi() % grass_scenes.size()]
	else:
		rot_idx = randi() % 4
		var mnt_val = mountain_noise.get_noise_2d(x * 2.0, z * 2.0)
		if mnt_val > 0.15 and not mountain_scenes.is_empty():
			chosen_scene = mountain_scenes[randi() % mountain_scenes.size()]
		elif not grass_scenes.is_empty():
			chosen_scene = grass_scenes[randi() % grass_scenes.size()]
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

