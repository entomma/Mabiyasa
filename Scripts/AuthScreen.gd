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
		
		if GameManager.player_party.size() == 0:
			get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")
		else:
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
