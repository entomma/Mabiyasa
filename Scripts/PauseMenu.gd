extends Control

@onready var resume_btn = $MenuPanel/MarginContainer/VBoxContainer/ResumeButton
@onready var chars_btn = $MenuPanel/MarginContainer/VBoxContainer/CharactersButton
@onready var party_btn = $MenuPanel/MarginContainer/VBoxContainer/PartyButton
@onready var wish_btn = $MenuPanel/MarginContainer/VBoxContainer/WishButton
@onready var quit_btn = $MenuPanel/MarginContainer/VBoxContainer/QuitButton

var is_quitting := false

func _ready():
	resume_btn.pressed.connect(_on_resume_pressed)
	chars_btn.pressed.connect(_on_characters_pressed)
	party_btn.pressed.connect(_on_party_pressed)
	wish_btn.pressed.connect(_on_wish_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	get_tree().paused = true

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()

func _on_resume_pressed():
	get_tree().paused = false
	queue_free()

func _on_characters_pressed():
	_save_current_state()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/CharacterDetails.tscn")

func _on_party_pressed():
	_save_current_state()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")

func _on_wish_pressed():
	_save_current_state()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/GachaScene.tscn")

func _on_quit_pressed():
	if is_quitting:
		return
	
	is_quitting = true
	_disable_buttons()
	_save_current_state()
	
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _disable_buttons():
	resume_btn.disabled = true
	chars_btn.disabled = true
	party_btn.disabled = true
	wish_btn.disabled = true
	quit_btn.disabled = true

func _save_current_state():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var current_pos = player.global_position
		GameManager.set_saved_position(current_pos)
		
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path != "":
			GameManager.set_meta("return_scene", current_scene.scene_file_path)
			print("📍 State saved - Scene: ", current_scene.scene_file_path, " Position: ", current_pos)
	
	if SupabaseManager.has_method("save_current_scene_and_position"):
		SupabaseManager.save_current_scene_and_position()
