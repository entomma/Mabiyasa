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

	# Tell spawn system BEFORE switching
	GameManager.next_spawn = spawn_name

	# ─────────────────────────────
	# WAIT WHILE TREE IS STILL VALID
	# ─────────────────────────────
	await get_tree().create_timer(0.05).timeout

	# ─────────────────────────────
	# SAFE SCENE SWITCH (NO AWAIT AFTER THIS)
	# ─────────────────────────────
	print("🚀 Switching scene...")
	get_tree().change_scene_to_file(target_scene)

	# DO NOT PUT ANY CODE AFTER THIS THAT USES get_tree()

	is_teleporting = false

func show_prompt():
	print("Press E to travel")

func hide_prompt():
	print("Prompt hidden")
