extends Control

# Custom Tabs
@onready var login_tab_btn = $CenterContainer/Wrapper/MainPanel/Margin/VBox/CustomTabs/LoginTab
@onready var register_tab_btn = $CenterContainer/Wrapper/MainPanel/Margin/VBox/CustomTabs/RegisterTab

# Containers
@onready var login_box = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/LoginBox
@onready var register_box = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/RegisterBox

# Login nodes
@onready var login_email = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/LoginBox/EmailInput
@onready var login_password = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/LoginBox/PasswordInput
@onready var login_btn = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/LoginBox/LoginButton

# Register nodes
@onready var reg_username = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/RegisterBox/UsernameInput
@onready var reg_email = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/RegisterBox/EmailInput
@onready var reg_password = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/RegisterBox/PasswordInput
@onready var register_btn = $CenterContainer/Wrapper/MainPanel/Margin/VBox/FormContainer/RegisterBox/RegisterButton

# Status
@onready var status_label = $CenterContainer/Wrapper/MainPanel/Margin/VBox/StatusLabel

const MAIN_SCENE = "res://Scenes/Game.tscn"

# --- Styling References ---
var style_active: StyleBoxFlat
var style_inactive: StyleBoxFlat
var color_active = Color(0.85, 0.75, 0.45, 1) # Gold
var color_inactive = Color(0.6, 0.65, 0.75, 1) # Grey

func _ready():
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Extract styles for dynamic switching
	style_active = login_tab_btn.get_theme_stylebox("normal").duplicate()
	style_inactive = register_tab_btn.get_theme_stylebox("normal").duplicate()
	
	# Connections
	login_tab_btn.pressed.connect(_show_login)
	register_tab_btn.pressed.connect(_show_register)
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	
	_show_login() # Default state

# ═══════════════════════════════════════════════════════
#  UI Tab Switching
# ═══════════════════════════════════════════════════════
func _show_login():
	login_box.visible = true
	register_box.visible = false
	status_label.text = ""
	
	login_tab_btn.add_theme_stylebox_override("normal", style_active)
	login_tab_btn.add_theme_stylebox_override("hover", style_active)
	login_tab_btn.add_theme_color_override("font_color", color_active)
	
	register_tab_btn.add_theme_stylebox_override("normal", style_inactive)
	register_tab_btn.add_theme_stylebox_override("hover", style_inactive)
	register_tab_btn.add_theme_color_override("font_color", color_inactive)

func _show_register():
	login_box.visible = false
	register_box.visible = true
	status_label.text = ""
	
	register_tab_btn.add_theme_stylebox_override("normal", style_active)
	register_tab_btn.add_theme_stylebox_override("hover", style_active)
	register_tab_btn.add_theme_color_override("font_color", color_active)
	
	login_tab_btn.add_theme_stylebox_override("normal", style_inactive)
	login_tab_btn.add_theme_stylebox_override("hover", style_inactive)
	login_tab_btn.add_theme_color_override("font_color", color_inactive)

# ═══════════════════════════════════════════════════════
#  Authentication Logic
# ═══════════════════════════════════════════════════════
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
		
		# --- FEED USER ID TO TUTORIAL MANAGER ---
		var user_id = ""
		if result.has("user") and result["user"] != null:
			user_id = result["user"].get("id", "")
		TutorialManager.load_tutorial_status(user_id)
		
		# Check if we have a saved scene in the profile
		var saved_scene = AccountManager.current_scene
		var has_saved_position = AccountManager.has_saved_position
		
		print("Login - Saved scene: ", saved_scene)
		print("Login - Has saved pos: ", has_saved_position)
		
		if saved_scene != "" and has_saved_position:
			GameManager.pending_zone = saved_scene
		else:
			GameManager.pending_zone = MAIN_SCENE
		get_tree().change_scene_to_file("res://Scenes/Game.tscn")
	else:
		if result.has("msg"):
			status_label.text = "Failed: " + result.msg
		elif result.has("error_description"):
			status_label.text = "Failed: " + result.error_description
		else:
			status_label.text = "Login Failed!"

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
			print("Profile after fetch: uid=", AccountManager.uid, " scene=", AccountManager.current_scene)
			
			# --- FEED NEW USER ID TO TUTORIAL MANAGER ---
			var user_id = ""
			if login_result.has("user") and login_result["user"] != null:
				user_id = login_result["user"].get("id", "")
			TutorialManager.load_tutorial_status(user_id)
			
			status_label.text = "Account created!"
			# New accounts go to MainMenu first
			get_tree().change_scene_to_file("res://Scenes/IntroCutscene.tscn")
		else:
			status_label.text = "Login after register failed!"
	else:
		if result.has("msg"):
			status_label.text = "Failed: " + result.msg
		elif result.has("message"):
			status_label.text = "Failed: " + result.message
		else:
			status_label.text = "Failed: " + str(result)
