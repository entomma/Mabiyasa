extends Area3D

@export_file("*.tscn") var target_scene: String
@export var spawn_name: String = "default"

var player_inside := false
var is_teleporting := false

func _input(event):
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
	if is_teleporting:
		return

	if target_scene == "" or target_scene == null:
		print("⚠ No target scene assigned!")
		return

	is_teleporting = true

	print("🚪 Teleport preparing...")

	# Small buffer so the interact input doesn't fire twice
	await get_tree().create_timer(0.05).timeout

	print("🚀 Switching zone...")
	await GameManager.load_zone(target_scene, spawn_name)

	is_teleporting = false

func show_prompt():
	print("Press E to travel")

func hide_prompt():
	print("Prompt hidden")
