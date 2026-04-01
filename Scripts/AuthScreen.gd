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
		
		# Load last scene or default to HubTown
		var last_scene = GameManager.player_profile.get("current_scene", "")
		
		if GameManager.player_party.size() == 0:
			# No party saved → go to party select first
			get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")
		elif last_scene != "":
			# Load last scene
			print("Loading last scene: ", last_scene)
			get_tree().change_scene_to_file("res://Scenes/" + last_scene + ".tscn")
		else:
			# Default to HubTown
			get_tree().change_scene_to_file("res://Scenes/HubTown.tscn")
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
		# Login first to get auth token
		var login_result = await SupabaseManager.login(email, password)
		print("Login result: ", login_result)
		
		if login_result.has("access_token"):
			# Create profile
			var profile_result = await SupabaseManager.create_player_profile(username)
			print("Profile result: ", profile_result)
			
			# Fetch profile AFTER creating it
			await SupabaseManager.fetch_player_profile()
			print("Profile after fetch: ", GameManager.player_profile)
			
			status_label.text = "Account created!"
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
	# Allow clicking to focus
	set_process_unhandled_input(true)
# Force the control to handle mouse input
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Make sure all children can receive input
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			
			
func _unhandled_input(event):
	if event is InputEventMouseButton:
		# Release focus when clicking outside inputs
		var focused = get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
