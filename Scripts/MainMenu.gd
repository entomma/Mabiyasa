extends Control

@onready var username_label = $TopBar/PlayerInfo/UsernameLabel
@onready var uid_label = $TopBar/PlayerInfo/UIDLabel
@onready var account_level = $TopBar/AccountLevel

func _ready():
	print("Player profile in GameManager: ", GameManager.player_profile)
	var profile = GameManager.player_profile
	
	if profile.size() > 0:
		username_label.text = profile.get("username", "Player")
		uid_label.text = "UID: " + str(int(profile.get("uid", 0)))
		account_level.text = "Level " + str(int(profile.get("account_level", 1)))
	else:
		username_label.text = "Player"
		uid_label.text = "UID: 00000"
		account_level.text = "Antas 1"

func _on_start_pressed():
	get_tree().change_scene_to_file("res://Scenes/small_village.tscn")

func _on_settings_pressed():
	pass  # Settings scene later

func _on_logout_pressed():
	# Clear player data
	GameManager.player_profile = {}
	SupabaseManager.auth_token = ""
	SupabaseManager.current_uid = 0
	SupabaseManager.current_user_id = ""
	# Go back to auth screen
	get_tree().change_scene_to_file("res://Scenes/AuthScreen.tscn")
