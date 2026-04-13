extends Area3D

@export_file("*.tscn") var target_scene: String 
@export var spawn_name: String = "default"

var player_inside := false

func _input(event):
	# Make sure "interact" is defined in Project Settings -> Input Map
	if player_inside and event.is_action_pressed("interact"): 
		teleport()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true
		show_prompt()

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false
		hide_prompt()

func teleport():
	# 1. Check if the Inspector variable is empty
	if target_scene == "" or target_scene == null:
		print("Warning: No target scene assigned in the Inspector!")
		return
	
	# 2. Tell GameManager where we want to land
	GameManager.next_spawn = spawn_name
	
	# 3. Use the VARIABLE, not a hardcoded path
	print("Teleporting to: ", target_scene)
	get_tree().change_scene_to_file(target_scene)

func show_prompt():
	print("Press E to travel")

func hide_prompt():
	print("Prompt hidden")
