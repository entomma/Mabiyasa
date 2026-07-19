@tool
extends CharacterBody3D

@export_category("NPC Identity")
@export var npc_frames: SpriteFrames:
	set(value):
		npc_frames = value
		if Engine.is_editor_hint() and has_node("AnimatedSprite3D"):
			$AnimatedSprite3D.sprite_frames = value

@export_category("NPC Behavior")
@export var can_wander := false
@export var move_speed := 2.0
@export var wander_radius := 3.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var wander_direction = Vector3.ZERO
var wander_timer := 0.0
var start_position: Vector3
var current_facing := "front"

@onready var animated_sprite = $AnimatedSprite3D

func _ready():

	if Engine.is_editor_hint():
		return

	start_position = global_position

	if npc_frames:
		animated_sprite.sprite_frames = npc_frames
		animated_sprite.play("idle_front")


func _physics_process(delta):

	if Engine.is_editor_hint():
		return

	if DialogueManager.is_active:
		velocity = Vector3.ZERO
		move_and_slide()
		update_animation()
		return

	if !is_on_floor():
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

	if is_on_wall() and can_wander:
		pick_new_direction()

	update_animation()


func pick_new_direction():

	if global_position.distance_to(start_position) > wander_radius:
		wander_direction = (start_position - global_position).normalized()
	else:
		wander_direction = Vector3(
			randf_range(-1,1),
			0,
			randf_range(-1,1)
		).normalized()

	wander_timer = randf_range(2.0,4.0)


func update_animation():

	if velocity.length() > 0.1:

		var camera = get_viewport().get_camera_3d()

		if camera:

			var cam_forward = -camera.global_transform.basis.z
			var cam_right = camera.global_transform.basis.x

			cam_forward.y = 0
			cam_right.y = 0

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
