extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003

const FLY_SPEED = 35.0
const FLY_SPRINT_SPEED = 80.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_flying: bool = false

@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
	# Tecla F para alternar o modo de voo livre
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			is_flying = not is_flying
			velocity = Vector3.ZERO
			print("[MODO VOO] ", "ATIVADO (Rápido)" if is_flying else "DESATIVADO")
			
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if is_flying:
		_process_flying(delta)
	else:
		_process_walking(delta)

func _process_flying(delta):
	var current_fly_speed = FLY_SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else FLY_SPEED
	
	# Direção 3D baseada para onde a câmera está olhando
	var move_vec = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		move_vec -= camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_vec += camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_vec -= camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_vec += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
		move_vec += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_C):
		move_vec += Vector3.DOWN
		
	if move_vec != Vector3.ZERO:
		velocity = move_vec.normalized() * current_fly_speed
	else:
		velocity = velocity.move_toward(Vector3.ZERO, current_fly_speed * 5.0 * delta)
		
	move_and_slide()

func _process_walking(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle Sprint.
	var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
