extends CharacterBody3D

const SPEED = 20.0
const SPRINT_SPEED = 35.0

@onready var anim = $AnimatedSprite3D
@onready var head = $Head
@onready var camera = $Head/SpringArm3D/Camera3D
@onready var interaction_detector = get_node_or_null("InteractionDetector")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var mouse_sensitivity := 0.003

const PITCH_MIN := deg_to_rad(-20)
const PITCH_MAX := deg_to_rad(20)

var current_facing_direction := Vector2.UP
var camera_yaw := 0.0
var camera_pitch := 0.0

var was_dialogue_active := false

# ── Fall detection ──────────────────────────────────────────
var last_ground_position: Vector3 = Vector3.ZERO
var fall_threshold: float = -20.0   # Y level below which we respawn


func _ready():
	add_to_group("player")
	await get_tree().process_frame

	# ── Spawn positioning ──────────────────────────────────
	var spawn_position: Vector3
	var found_spawn := false

	if GameManager.next_spawn != "":
		var spawn_points = get_tree().get_nodes_in_group("spawn")
		for sp in spawn_points:
			if sp.name == GameManager.next_spawn:
				spawn_position = sp.global_position
				found_spawn = true
				break
		if not found_spawn:
			print("⚠ Spawn point '", GameManager.next_spawn, "' not found, using fallback.")
			var fallback_sp = get_tree().get_nodes_in_group("spawn")
			if fallback_sp.size() > 0:
				spawn_position = fallback_sp[0].global_position
				found_spawn = true
			else:
				spawn_position = Vector3.ZERO
				found_spawn = true

	if not found_spawn:
		if GameManager.current_zone_path == AccountManager.current_scene and AccountManager.has_saved_position:
			spawn_position = AccountManager.saved_position
			found_spawn = true
			print("✓ Loaded saved position:", spawn_position)
		else:
			var spawn_points = get_tree().get_nodes_in_group("spawn")
			if spawn_points.size() > 0:
				var default_sp = null
				for sp in spawn_points:
					if sp.name == "default":
						default_sp = sp
						break
				if default_sp:
					spawn_position = default_sp.global_position
				else:
					spawn_position = spawn_points[0].global_position
				found_spawn = true
			else:
				spawn_position = Vector3.ZERO
				found_spawn = true

	global_position = spawn_position
	last_ground_position = global_position

	# ── Safety: prevent falling through terrain at load ──
	await get_tree().physics_frame
	if global_position.y < fall_threshold:
		print("⚠ Player below terrain, repositioning to safe height.")
		_respawn_to_safe_position()

	# ── Input & camera ────────────────────────────────────
	if TutorialManager.current_step == "intro" or TutorialManager.current_step == "":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	head.position.y = 1.33
	camera_yaw = rotation.y
	camera_pitch = 0.0

	GameManager.next_spawn = ""


func _physics_process(delta):
	# ── Safely check dialogue state ──────────────────────────
	# Use .get() with a single argument, then handle null
	var is_dialogue_active = DialogueManager.is_active

	if was_dialogue_active and !is_dialogue_active:
		if TutorialManager.current_active_step == "interact":
			TutorialManager.record_interaction()

	was_dialogue_active = is_dialogue_active

	if is_dialogue_active:
		velocity = Vector3.ZERO
		play_idle()
		move_and_slide()
		return

	# ── Movement ──────────────────────────────────────────
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

	if !is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
		# Update last known ground position when on floor
		last_ground_position = global_position

	move_and_slide()

	# ── Fall detection ──────────────────────────────────────
	if global_position.y < fall_threshold:
		print("⚠ Player fell below world! Respawning...")
		_respawn_to_safe_position()

	# ── Camera & animations ────────────────────────────────
	rotation.y = camera_yaw
	head.rotation.x = camera_pitch
	camera.global_position = global_position + Vector3(0, head.position.y, 0)

	if input == Vector2.ZERO:
		play_idle()
	else:
		play_walk(input)


func _input(event):
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
				area.interact()
				break


# ─── Respawn helper ─────────────────────────────────────────
func _respawn_to_safe_position() -> void:
	# Try to find the last checkpoint or a spawn point
	var target_pos: Vector3 = last_ground_position

	# If we have a checkpoint saved in AccountManager
	if AccountManager.last_checkpoint != "":
		# Look for a checkpoint node with that ID in the current zone
		var checkpoints = get_tree().get_nodes_in_group("checkpoint")
		for cp in checkpoints:
			if cp.has_method("get_checkpoint_id") and cp.get_checkpoint_id() == AccountManager.last_checkpoint:
				target_pos = cp.global_position
				break

	# If no checkpoint found, try the default spawn
	if target_pos == last_ground_position:
		var spawn_points = get_tree().get_nodes_in_group("spawn")
		if spawn_points.size() > 0:
			target_pos = spawn_points[0].global_position

	# Place the player
	global_position = target_pos + Vector3(0, 1.5, 0)  # slightly above ground
	velocity = Vector3.ZERO

	# Force a ground check
	await get_tree().physics_frame
	if global_position.y < fall_threshold:
		# If still below, just place at a safe height (0, 5, 0)
		global_position = Vector3(global_position.x, 5.0, global_position.z)

	print("✓ Respawned player to safe position: ", global_position)


# ─── Animation helpers ──────────────────────────────────────
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
