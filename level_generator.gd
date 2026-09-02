extends Node3D

@export var tile_scenes: Array[PackedScene] = []
@export var grid_size_x: int = 20
@export var grid_size_z: int = 20
@export var tile_spacing: float = 4.0
@export var noise_threshold: float = 0.2

var noise = FastNoiseLite.new()

func _ready():
	if tile_scenes.is_empty():
		print("Warning: No tile scenes assigned to the level generator.")
		return
		
	generate_island()

func generate_island():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	var center_x = grid_size_x / 2.0
	var center_z = grid_size_z / 2.0
	var max_radius = min(center_x, center_z)

	for x in range(grid_size_x):
		for z in range(grid_size_z):
			# Distancia pro centro para fazer formato de ilha
			var distance_to_center = Vector2(x - center_x, z - center_z).length()
			var falloff = distance_to_center / max_radius
			
			var noise_val = noise.get_noise_2d(x * 10, z * 10)
			
			# Combina noise com o falloff para formar uma ilha natural
			var final_val = noise_val - (falloff * falloff * 1.5)
			
			if final_val > -noise_threshold:
				spawn_tile(x, z)

func spawn_tile(x: int, z: int):
	# Escolhe um tile aleatório da lista
	var tile_index = randi() % tile_scenes.size()
	var tile_instance = tile_scenes[tile_index].instantiate()
	
	add_child(tile_instance)
	
	# Posiciona o tile
	tile_instance.position = Vector3(x * tile_spacing, 0, z * tile_spacing)
	
	# Rotação aleatória pra dar variedade (supondo que os tiles encaixam bem)
	var random_rot = (randi() % 4) * (PI / 2.0)
	tile_instance.rotation.y = random_rot
