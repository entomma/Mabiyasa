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
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
	
	
