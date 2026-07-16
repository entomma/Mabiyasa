extends CharacterBody3D

const SPEED = 20.0
const SPRINT_SPEED = 35.0

@onready var anim = $AnimatedSprite3D
@onready var head = $Head
@onready var camera = $Head/SpringArm3D/Camera3D
@onready var interaction_detector = get_node_or_null("InteractionDetector")

var pause_menu_scene = preload("res://Scenes/PauseMenu.tscn")
var pause_menu_instance = null

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var mouse_sensitivity := 0.003

const PITCH_MIN := deg_to_rad(-20)
const PITCH_MAX := deg_to_rad(20)

var current_facing_direction := Vector2.UP
var camera_yaw := 0.0
var camera_pitch := 0.0

# Track the dialogue state from the previous frame to detect when it closes
var was_dialogue_active := false


func _ready():
	add_to_group("player")
	await get_tree().process_frame

	var spawn_points = get_tree().get_nodes_in_group("spawn")
	var spawned := false
	for sp in spawn_points:
		if sp.name == GameManager.next_spawn:
			global_position = sp.global_position
			spawned = true
			break
	if not spawned and GameManager.has_saved_position:
		global_position = GameManager.saved_player_position

	if TutorialManager.current_step == "intro" or TutorialManager.current_step == "":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	head.position.y = 1.33
	camera_yaw = rotation.y
	camera_pitch = 0.0


func _physics_process(delta):
	var diag = get_node_or_null("/root/DialogueManager")
	var is_dialogue_active = diag and diag.is_dialogue_active
	
	# DETECT WHEN DIALOGUE CLOSES:
	if was_dialogue_active and not is_dialogue_active:
		if TutorialManager.current_active_step == "interact":
			TutorialManager.record_interaction() # Completes the tutorial step when conversation ends!
			
	was_dialogue_active = is_dialogue_active # Keep tracking state

	if is_dialogue_active:
		velocity = Vector3.ZERO
		play_idle()
		move_and_slide()
		return

	var input = Vector2.ZERO
	if TutorialManager.movement_allowed:
		input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var direction = (transform.basis * Vector3(input.x, 0, input.y)).normalized()

	if direction:
		var current_speed = SPEED
		
		if Input.is_action_pressed("Sprint") and TutorialManager.sprint_allowed:
			current_speed = SPRINT_SPEED
			TutorialManager.record_sprint()
			
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		current_facing_direction = input.normalized()
		
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		TutorialManager.record_walk(horizontal_velocity.length() * delta)
	else:
		velocity.x = 0
		velocity.z = 0

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

	rotation.y = camera_yaw
	head.rotation.x = camera_pitch
	camera.global_position = global_position + Vector3(0, head.position.y, 0)

	if input == Vector2.ZERO:
		play_idle()
	else:
		play_walk(input)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if pause_menu_instance == null:
			pause_menu_instance = pause_menu_scene.instantiate()
			pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().root.add_child(pause_menu_instance)
			pause_menu_instance.tree_exiting.connect(_on_pause_menu_closed)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("interact") and TutorialManager.interact_allowed:
		execute_interaction()

	if event is InputEventMouseMotion and TutorialManager.camera_allowed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			camera_yaw -= event.relative.x * mouse_sensitivity
			camera_pitch -= event.relative.y * mouse_sensitivity
			camera_pitch = clamp(camera_pitch, PITCH_MIN, PITCH_MAX)
			
			var travel = abs(event.relative.x) * mouse_sensitivity
			TutorialManager.record_camera_turn(travel)


func execute_interaction() -> void:
	if interaction_detector:
		var overlapping_areas = interaction_detector.get_overlapping_areas()
		for area in overlapping_areas:
			if area.has_method("interact"):
				area.interact() # Play dialogue normally
				break 


func play_walk(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		anim.play("walk right" if dir.x > 0 else "walk left")
	else:
		anim.play("walk front" if dir.y > 0 else "walk back")


func play_idle():
	if abs(current_facing_direction.x) > abs(current_facing_direction.y):
		anim.play("idle right" if current_facing_direction.x > 0 else "idle left")
	else:
		anim.play("idle back" if current_facing_direction.y < 0 else "idle front")


func _on_pause_menu_closed():
	pause_menu_instance = null
	if TutorialManager.current_step != "intro" and TutorialManager.current_step != "":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
