extends CharacterBody3D

const SPEED = 7.0

@onready var anim = $AnimatedSprite3D
@onready var head = $Head
@onready var camera = $Head/SpringArm3D/Camera3D

var pause_menu_scene = preload("res://Scenes/PauseMenu.tscn")
var pause_menu_instance = null

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- CAMERA ---
@export var sensitivity := 0.0020
var camera_yaw := 0.0
var camera_pitch := 0.0

const PITCH_MIN := deg_to_rad(-60)
const PITCH_MAX := deg_to_rad(60)


func _ready():
	add_to_group("player")

	await get_tree().process_frame

	# =========================
	# 1. ZONE SPAWN (priority)
	# =========================
	var spawn_points = get_tree().get_nodes_in_group("spawn")
	var spawned := false

	for sp in spawn_points:
		if sp.name == GameManager.next_spawn:
			global_position = sp.global_position
			spawned = true
			break

	# =========================
	# 2. SAVE POSITION (fallback)
	# =========================
	if not spawned and GameManager.has_saved_position:
		global_position = GameManager.saved_player_position

	# =========================
	# CAMERA INIT
	# =========================
	camera_yaw = rotation.y
	camera_pitch = head.rotation.x

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	head.position.y = 1.5

func _physics_process(delta):
	# --- INPUT ---
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = Vector3(input.x, 0, input.y)

	if direction.length() > 0:
		direction = direction.normalized()

	# --- MOVEMENT ---
	var move_dir = transform.basis * direction
	velocity.x = move_dir.x * SPEED
	velocity.z = move_dir.z * SPEED

	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

	# --- ROTATION ---
	rotation.y = camera_yaw
	head.rotation.x = camera_pitch

	# --- ANIMATION ---
	if input == Vector2.ZERO:
		play_idle()
	else:
		play_walk(input)


func _input(event):
	# --- ALT KEY ---
	if event is InputEventKey:
		if event.keycode == KEY_ALT:
			Input.set_mouse_mode(
				Input.MOUSE_MODE_VISIBLE if event.pressed else Input.MOUSE_MODE_CAPTURED
			)

	# --- PAUSE ---
	if event.is_action_pressed("ui_cancel"):
		if pause_menu_instance == null:
			pause_menu_instance = pause_menu_scene.instantiate()
			pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().root.add_child(pause_menu_instance)
			pause_menu_instance.tree_exiting.connect(_on_pause_menu_closed)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# --- CAMERA ---
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			camera_yaw -= event.relative.x * sensitivity
			camera_pitch -= event.relative.y * sensitivity

			camera_pitch = clamp(camera_pitch, PITCH_MIN, PITCH_MAX)


func play_walk(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		anim.play("walk right" if dir.x > 0 else "walk left")
	else:
		anim.play("walk back" if dir.y > 0 else "walk front")


func play_idle():
	anim.play("idle front")


func _on_pause_menu_closed():
	pause_menu_instance = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
