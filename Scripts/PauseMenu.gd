extends Control

@onready var resume_btn = $MenuPanel/VBoxContainer/ResumeButton
@onready var party_btn = $MenuPanel/VBoxContainer/PartyButton
@onready var quit_btn = $MenuPanel/VBoxContainer/QuitButton

func _ready():
	resume_btn.pressed.connect(_on_resume_pressed)
	party_btn.pressed.connect(_on_party_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	get_tree().paused = true

# Handle Escape key to close menu
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()

func _on_resume_pressed():
	get_tree().paused = false
	queue_free()

func _on_party_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Get current scene name
		var scene_path = get_tree().current_scene.scene_file_path
		var scene_name = scene_path.get_file().replace(".tscn", "")
		GameManager.set_saved_position(player.global_position)
		SupabaseManager.save_checkpoint("pause_save", scene_name, player.global_position)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
	
	
