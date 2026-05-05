@tool
extends CharacterBody3D

# --- SETTINGS ---
@export_category("NPC Identity")
@export var npc_frames: SpriteFrames:
	set(value):
		npc_frames = value
		if Engine.is_editor_hint() and has_node("AnimatedSprite3D"):
			$AnimatedSprite3D.sprite_frames = value

@export_multiline var dialogue_text: String = "Hello!|Mengan na ka?" 

@export_category("NPC Behavior")
@export var can_wander: bool = false 
@export var move_speed: float = 2.0
@export var wander_radius: float = 3.0

# --- INTERNAL ---
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var wander_direction = Vector3.ZERO
var wander_timer = 0.0
var player_in_range = false
var current_player: Node3D = null
var start_position: Vector3 
var current_facing: String = "front" 

@onready var animated_sprite = $AnimatedSprite3D

func _ready():
	if Engine.is_editor_hint(): return
	start_position = global_position
	if npc_frames:
		animated_sprite.sprite_frames = npc_frames
		animated_sprite.play("idle_front") 

func _physics_process(delta):
	if Engine.is_editor_hint(): return

	# --- 1. THE FREEZE CHECK ---
	var diag = get_node_or_null("/root/DialogueManager")
	if diag and diag.is_dialogue_active:
		velocity = Vector3.ZERO # Wipe all speed
		move_and_slide() # Stick to ground
		update_animation() # This will force the idle animation
		return # STOP HERE - do not run wandering logic

	if not is_on_floor():
		velocity.y -= gravity * delta

	if can_wander:
		if wander_timer > 0:
			wander_timer -= delta
			velocity.x = wander_direction.x * move_speed
			velocity.z = wander_direction.z * move_speed
		else:
			pick_new_direction()
	else:
		velocity.x = 0
		velocity.z = 0
		
	move_and_slide()
	if is_on_wall() and can_wander: pick_new_direction()
	update_animation()

func pick_new_direction():
	if global_position.distance_to(start_position) > wander_radius:
		wander_direction = (start_position - global_position).normalized()
	else:
		wander_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	wander_timer = randf_range(2.0, 4.0) 

func update_animation():
	if velocity.length() > 0.1:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var cam_forward = -camera.global_transform.basis.z
			var cam_right = camera.global_transform.basis.x
			cam_forward.y = 0; cam_right.y = 0
			var move_dir = velocity.normalized()
			var forward_amount = move_dir.dot(cam_forward.normalized())
			var right_amount = move_dir.dot(cam_right.normalized())
			if abs(right_amount) > abs(forward_amount):
				current_facing = "right" if right_amount > 0 else "left"
			else:
				current_facing = "back" if forward_amount > 0 else "front"
		animated_sprite.play("walk_" + current_facing)
	else:
		animated_sprite.play("idle_" + current_facing)

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		current_player = body 

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		current_player = null

func _input(event):
	if event.is_action_pressed("interact") and player_in_range:
		var diag = get_node_or_null("/root/DialogueManager")
		if diag and not diag.is_dialogue_active:
			diag.start_dialogue(self, current_player, dialogue_text)
			# --- 2. THE INPUT STOPPER ---
			get_viewport().set_input_as_handled() # Prevents dialogue from closing immediately
