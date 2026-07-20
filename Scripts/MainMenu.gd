extends Control

@onready var username_label = $TopBar/PlayerInfo/UsernameLabel
@onready var uid_label = $TopBar/PlayerInfo/UIDLabel
@onready var account_level = $TopBar/AccountLevel

func _ready():
	print("Account loaded: uid=", AccountManager.uid, " username=", AccountManager.username)
	
	if AccountManager.is_logged_in():
		username_label.text = AccountManager.username if AccountManager.username != "" else "Player"
		uid_label.text = "UID: " + str(AccountManager.uid)
		account_level.text = "Level " + str(ProgressManager.account_level)
	else:
		username_label.text = "Player"
		uid_label.text = "UID: 00000"
		account_level.text = "Antas 1"

func _on_start_pressed():
	# Get saved scene from AccountManager
	var last_scene = AccountManager.current_scene
	
	# Debug: Print what we're trying to load
	print("Raw saved scene path: '", last_scene, "'")
	
	# Validate and fix the scene path
	if last_scene != "" and last_scene != null:
		# Ensure it has .tscn extension
		if not last_scene.ends_with(".tscn"):
			# Try to add .tscn
			if last_scene.begins_with("res://"):
				last_scene = last_scene + ".tscn"
			else:
				# Assume it's just a scene name like "forest"
				last_scene = "res://Scenes/" + last_scene + ".tscn"
		
		print("Fixed scene path: '", last_scene, "'")
		
		# Check if file exists
		if ResourceLoader.exists(last_scene):
			print("Loading saved scene: ", last_scene)
			
			# Restore saved position (AccountManager already parsed this at login)
			if AccountManager.has_saved_position:
				print("Restoring position: ", AccountManager.saved_position)
			
			# Clear teleport spawn (use saved position instead)
			GameManager.next_spawn = ""
			
			# Route into the persistent Game.tscn shell, which will load this zone
			GameManager.pending_zone = last_scene
			get_tree().change_scene_to_file("res://Scenes/Game.tscn")
			return
		else:
				
			print("⚠ Saved scene file does not exist: ", last_scene)
	
	# Fallback to village
	print("No valid saved scene found, loading default village")
	GameManager.next_spawn = "VillageSpawn"
	GameManager.pending_zone = "res://Scenes/small_village.tscn"
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_settings_pressed():
	pass

func _on_logout_pressed():
	AccountManager.clear()
	SupabaseManager.auth_token = ""
	SupabaseManager.current_uid = 0
	SupabaseManager.current_user_id = ""
	get_tree().change_scene_to_file("res://Scenes/AuthScreen.tscn")
