extends Control

@onready var resume_btn = $MenuPanel/VBoxContainer/ResumeButton
@onready var party_btn = $MenuPanel/VBoxContainer/PartyButton
@onready var quit_btn = $MenuPanel/VBoxContainer/QuitButton
@onready var wish_btn = $MenuPanel/VBoxContainer/WishButton

var is_quitting := false  # Prevent multiple quit attempts

func _ready():
	resume_btn.pressed.connect(_on_resume_pressed)
	party_btn.pressed.connect(_on_party_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	wish_btn.pressed.connect(_on_wish_pressed)
	get_tree().paused = true

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()

func _on_resume_pressed():
	get_tree().paused = false
	queue_free()

func _on_party_pressed():
	_save_current_state()  # Save position AND scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")

func _on_wish_pressed():
	_save_current_state()  # Save position AND scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/GachaScene.tscn")

func _on_quit_pressed():
	if is_quitting:
		return  # Already quitting
	
	is_quitting = true
	
	# Disable buttons to prevent multiple clicks
	resume_btn.disabled = true
	party_btn.disabled = true
	quit_btn.disabled = true
	wish_btn.disabled = true
	
	# Save without await - fire and forget
	_save_current_state()
	
	# Small delay to let save start, then quit
	await get_tree().create_timer(0.1).timeout
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# Helper function to save current player state
func _save_current_state():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Save position
		var current_pos = player.global_position
		GameManager.set_saved_position(current_pos)
		
		# Save current scene path
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path != "":
			GameManager.set_meta("return_scene", current_scene.scene_file_path)
			print("📍 State saved - Scene: ", current_scene.scene_file_path, " Position: ", current_pos)
	
	# Also try to save to database (fire and forget)
	SupabaseManager.save_current_scene_and_position()
