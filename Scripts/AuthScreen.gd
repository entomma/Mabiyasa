extends Control

@onready var status_label = $StatusLabel
@onready var tab_container = $CenterContainer/PanelContainer/VBoxContainer/TabContainer

# Login nodes
@onready var login_email = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Login/EmailInput
@onready var login_password = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Login/PasswordInput

# Register nodes
@onready var reg_username = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Register/UsernameInput
@onready var reg_email = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Register/EmailInput
@onready var reg_password = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Register/PasswordInput

const MAIN_SCENE = "res://Scenes/small_village.tscn"

func _on_login_pressed():
	status_label.text = "Logging in..."
	var email = login_email.text
	var password = login_password.text
	
	if email == "" or password == "":
		status_label.text = "Please fill in all fields!"
		return
	
	var result = await SupabaseManager.login(email, password)
	
	if result.has("access_token"):
		status_label.text = "Login successful!"
		
		# Check if we have a saved scene in the profile
		var saved_scene = GameManager.player_profile.get("current_scene", "")
		var has_saved_position = GameManager.has_saved_position
		
		print("Login - Saved scene: ", saved_scene)
		print("Login - Has saved position: ", has_saved_position)
		print("Login - Player party size: ", GameManager.player_party.size())
		
		# Priority 1: If player has no party, go to party select first
		if GameManager.player_party.size() == 0:
			print("No party found, going to PartySelect")
			get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")
		# Priority 2: If we have a saved scene AND saved position, go there
		elif saved_scene != "" and saved_scene != null and has_saved_position:
			print("Loading saved scene: ", saved_scene)
			# Clear any pending teleport spawn (use saved position instead)
			GameManager.next_spawn = ""
			get_tree().change_scene_to_file(saved_scene)
		# Priority 3: If we have a saved scene but no position, still go there (will use spawn point)
		elif saved_scene != "" and saved_scene != null:
			print("Loading saved scene (no position): ", saved_scene)
			GameManager.next_spawn = ""  # Will use scene's default spawn
			get_tree().change_scene_to_file(saved_scene)
		# Priority 4: Fallback to main scene (small village)
		else:
			print("No saved scene found, loading default village")
			GameManager.next_spawn = "VillageSpawn"
			get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		status_label.text = "Login failed! Check your credentials."

func _on_register_pressed():
	status_label.text = "Registering..."
	var username = reg_username.text
	var email = reg_email.text
	var password = reg_password.text
	
	if username == "" or email == "" or password == "":
		status_label.text = "Please fill in all fields!"
		return
	
	if password.length() < 6:
		status_label.text = "Password must be at least 6 characters!"
		return
	
	var result = await SupabaseManager.register(email, username, password)
	print("Register result: ", result)
	
	if result.has("user") or result.has("id") or result.has("access_token"):
		var login_result = await SupabaseManager.login(email, password)
		print("Login result: ", login_result)
		
		if login_result.has("access_token"):
			var profile_result = await SupabaseManager.create_player_profile(username)
			print("Profile result: ", profile_result)
			
			await SupabaseManager.fetch_player_profile()
			print("Profile after fetch: ", GameManager.player_profile)
			
			status_label.text = "Account created!"
			# New accounts go to MainMenu first
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
		else:
			status_label.text = "Login after register failed!"
	else:
		if result.has("msg"):
			status_label.text = "Failed: " + result.msg
		elif result.has("message"):
			status_label.text = "Failed: " + result.message
		else:
			status_label.text = "Failed: " + str(result)

func _ready():
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS

func _unhandled_input(event):
	if event is InputEventMouseButton:
		var focused = get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
