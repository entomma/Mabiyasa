extends CharacterBody3D

const SPEED = 5.0

@onready var anim = $AnimatedSprite3D
@export var camera: Camera3D
var pause_menu_scene = preload("res://Scenes/PauseMenu.tscn")
var pause_menu_instance = null


func _ready():
	
	if camera:
		camera.global_position = Vector3(
			global_position.x,
			global_position.y + .5,
			global_position.z + 1.5
		)
		camera.rotation_degrees = Vector3(-20, 0, 0)

func _physics_process(delta):
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var direction = Vector3(input.x, 0, input.y)
	
	if direction.length() > 0:
		direction = direction.normalized()
	
	velocity = direction * SPEED
	move_and_slide()
	
	# Camera follows player
	if camera:
		var target_pos = Vector3(
			global_position.x,
			global_position.y + .5,
			global_position.z + 1.5
		)
		camera.global_position = camera.global_position.lerp(target_pos, .9)
	
	# Animation
	if input == Vector2.ZERO:
		play_idle()
	else:
		play_walk(input)

func play_walk(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			anim.play("walk right")
		else:
			anim.play("walk left")
	else:
		if dir.y > 0:
			anim.play("walk back")
		else:
			anim.play("idle front")

func play_idle():
	anim.play("idle front")
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if pause_menu_instance == null:
			pause_menu_instance = pause_menu_scene.instantiate()
			pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().root.add_child(pause_menu_instance)
			pause_menu_instance.tree_exiting.connect(_on_pause_menu_closed)
		# Don't handle escape here if menu is open
		# PauseMenu handles its own escape

func _on_pause_menu_closed():
	pause_menu_instance = null
