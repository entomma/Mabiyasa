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
	# Get saved scene from profile
	var last_scene = GameManager.player_profile.get("current_scene", "")
	
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
			
			# Restore saved position
			var last_pos_x = float(GameManager.player_profile.get("last_pos_x", 0))
			var last_pos_y = float(GameManager.player_profile.get("last_pos_y", 0))
			var last_pos_z = float(GameManager.player_profile.get("last_pos_z", 0))
			
			if last_pos_x != 0 or last_pos_y != 0 or last_pos_z != 0:
				GameManager.set_saved_position(Vector3(last_pos_x, last_pos_y, last_pos_z))
				print("Restoring position: ", Vector3(last_pos_x, last_pos_y, last_pos_z))
			
			# Clear teleport spawn (use saved position instead)
			GameManager.next_spawn = ""
			
			# Load the scene
			get_tree().change_scene_to_file(last_scene)
			return
		else:
			print("⚠ Saved scene file does not exist: ", last_scene)
	
	# Fallback to village
	print("No valid saved scene found, loading default village")
	GameManager.next_spawn = "VillageSpawn"
	get_tree().change_scene_to_file("res://Scenes/small_village.tscn")

func _on_settings_pressed():
	pass

func _on_logout_pressed():
	GameManager.player_profile = {}
	SupabaseManager.auth_token = ""
	SupabaseManager.current_uid = 0
	SupabaseManager.current_user_id = ""
	get_tree().change_scene_to_file("res://Scenes/AuthScreen.tscn")
