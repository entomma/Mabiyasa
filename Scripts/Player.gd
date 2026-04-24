extends CharacterBody3D

const SPEED = 20.0

@onready var anim = $AnimatedSprite3D
@onready var head = $Head
@onready var camera = $Head/SpringArm3D/Camera3D

var pause_menu_scene = preload("res://Scenes/PauseMenu.tscn")
var pause_menu_instance = null

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var mouse_sensitivity := 0.003

# Y axis (pitch) limited to 45 degrees up/down
const PITCH_MIN := deg_to_rad(-20)
const PITCH_MAX := deg_to_rad(20)

var current_facing_direction := Vector2.UP  # Track which direction player is facing
var camera_yaw := 0.0  # X axis (unlimited rotation)
var camera_pitch := 0.0  # Y axis (limited rotation)


func _ready():
	add_to_group("player")

	await get_tree().process_frame

	# Spawn logic
	var spawn_points = get_tree().get_nodes_in_group("spawn")
	var spawned := false

	for sp in spawn_points:
		if sp.name == GameManager.next_spawn:
			global_position = sp.global_position
			spawned = true
			break

	if not spawned and GameManager.has_saved_position:
		global_position = GameManager.saved_player_position

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	head.position.y = 1.33
	
	# Initialize camera rotation
	camera_yaw = rotation.y
	camera_pitch = 0.0


func _physics_process(delta):
	# Movement input
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input.x, 0, input.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		# Update facing direction based on movement
		current_facing_direction = input.normalized()
	else:
		velocity.x = 0
		velocity.z = 0

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

	# Apply camera rotation
	rotation.y = camera_yaw
	head.rotation.x = camera_pitch

	# Keep camera centered on player
	camera.global_position = global_position + Vector3(0, head.position.y, 0)

	# Animation
	if input == Vector2.ZERO:
		play_idle()
	else:
		play_walk(input)


func _input(event):
	# ALT toggle mouse
	if event is InputEventKey:
		if event.keycode == KEY_ALT:
			Input.set_mouse_mode(
				Input.MOUSE_MODE_VISIBLE if event.pressed else Input.MOUSE_MODE_CAPTURED
			)

	# Pause
	if event.is_action_pressed("ui_cancel"):
		if pause_menu_instance == null:
			pause_menu_instance = pause_menu_scene.instantiate()
			pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().root.add_child(pause_menu_instance)
			pause_menu_instance.tree_exiting.connect(_on_pause_menu_closed)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Camera movement - X axis (yaw) flat/unlimited, Y axis (pitch) 45 degrees
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			# X axis - unlimited horizontal rotation
			camera_yaw -= event.relative.x * mouse_sensitivity
			
			# Y axis - limited to 45 degrees up/down
			camera_pitch -= event.relative.y * mouse_sensitivity
			camera_pitch = clamp(camera_pitch, PITCH_MIN, PITCH_MAX)


func play_walk(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		anim.play("walk right" if dir.x > 0 else "walk left")
	else:
		anim.play("walk front" if dir.y > 0 else "walk back")


func play_idle():
	# Play idle animation based on last facing direction
	if abs(current_facing_direction.x) > abs(current_facing_direction.y):
		anim.play("idle right" if current_facing_direction.x > 0 else "idle left")
	else:
		anim.play("idle back" if current_facing_direction.y < 0 else "idle front")


func _on_pause_menu_closed():
	pause_menu_instance = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
