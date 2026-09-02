extends Node3D

var grass_scenes: Array[PackedScene] = []
var mountain_scenes: Array[PackedScene] = []

@export var grid_size_x: int = 10
@export var grid_size_z: int = 10
@export var tile_spacing: float = 100.0
var mountain_noise = FastNoiseLite.new()

var palette_material: ShaderMaterial

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
		
		// Amostra o ruído global contínuo no espaço do mundo
		float n = textureLod(noise_texture, world_pos.xz * 0.001, 0.0).r;
		
		vec2 uv = UV;
		
		// O atlas CPT_Terrain_Texture_Atlas_01 é dividido em 4 quadrantes exatos:
		// Top-Left (x < 0.5, y < 0.5)     = GRAMA VERDE (#98d276)
		// Top-Right (x >= 0.5, y < 0.5)    = NEVE BRANCA (#ffffff)
		// Bottom-Left (x < 0.5, y >= 0.5)  = PEDRA CINZA (#a3a39b)
		// Bottom-Right (x >= 0.5, y >= 0.5)= AREIA/DESERTO (#ccbc84)
		
		// Apenas as faces de chão/grama (x < 0.5, y < 0.5) são alteradas para os biomas.
		// Os paredões de pedra das montanhas (y >= 0.5) permanecem sempre como pedra!
		if (uv.x < 0.5 && uv.y < 0.5) {
			if (n > 0.80) {
				// Neve: bioma menor (aprox. 15% do mapa)
				uv.x += 0.5;
			} else if (n < 0.28) {
				// Areia/Praia: bioma intermediário (aprox. 25-30% do mapa, maior que a neve)
				uv.x += 0.5;
				uv.y += 0.5;
			}
			// O restante (aprox. 55-60% do mapa) permanece como o bioma principal: GRAMA VERDE!
		}
		
		final_uv = uv;
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
				# Carrega todas as planícies e colinas de grama (letras b até g)
				if file_name.begins_with("CPT_Terrain_L_") and not file_name.begins_with("CPT_Terrain_L_a_"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						grass_scenes.append(scene)
				# Carrega todas as montanhas escarpadas
				elif file_name.begins_with("MT_Terrain_L_"):
					var scene = load("res://Assets/TerrainModels/" + file_name)
					if scene is PackedScene:
						mountain_scenes.append(scene)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

func generate_island():
	mountain_noise.seed = randi()
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = 0.08
	
	var center_x = (grid_size_x - 1) / 2.0
	var center_z = (grid_size_z - 1) / 2.0
	var player = get_node_or_null("../Player")
	if player:
		player.position = Vector3((grid_size_x * tile_spacing) / 2.0, 35.0, (grid_size_z * tile_spacing) / 2.0)

	# Preenche 100% das células do mapa garantindo que não falte nenhum módulo
	for x in range(grid_size_x):
		for z in range(grid_size_z):
			spawn_tile(x, z)

func spawn_tile(x: int, z: int):
	# Agrupa montanhas de forma suave em cadeias
	var mnt_val = mountain_noise.get_noise_2d(x * 2.0, z * 2.0)
	
	var chosen_scene: PackedScene = null
	
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
	
	# Sorteia rotação modular de 90 em 90 graus para dar rica variedade ao terreno
	var rot_idx = randi() % 4
	tile_instance.rotation.y = rot_idx * (PI / 2.0)
	
	# Compensa o pivô interno dos modelos FBX (que já possuem rotação de 180° importada do Blender/FBX)
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

