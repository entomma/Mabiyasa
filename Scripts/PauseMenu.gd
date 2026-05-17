extends Control

# --- Node References ---
@onready var btn_resume = $RightPanel/Margin/VBox/BottomBar/BtnResume
@onready var btn_quit = $RightPanel/Margin/VBox/BottomBar/BtnQuit

@onready var btn_store = $RightPanel/Margin/VBox/GridMenu/BtnStore
@onready var btn_friends = $RightPanel/Margin/VBox/GridMenu/BtnFriends
@onready var btn_chars = $RightPanel/Margin/VBox/GridMenu/BtnCharacters
@onready var btn_party = $RightPanel/Margin/VBox/GridMenu/BtnParty
@onready var btn_wish = $RightPanel/Margin/VBox/GridMenu/BtnWish
@onready var btn_missions = $RightPanel/Margin/VBox/GridMenu/BtnMissions
@onready var btn_inventory = $RightPanel/Margin/VBox/GridMenu/BtnInventory

# Profile labels
@onready var name_label = $RightPanel/Margin/VBox/ProfileSection/Info/NameLabel
@onready var level_uid_label = $RightPanel/Margin/VBox/ProfileSection/Info/LevelUID

var is_quitting := false

func _ready():
	# Allow process mode to run while tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# Load Profile Data
	_load_profile_data()
	
	# Connect Core Buttons
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_party.pressed.connect(_on_party_pressed)
	btn_wish.pressed.connect(_on_wish_pressed)
	btn_chars.pressed.connect(_on_characters_pressed)
	
	# Connect Placeholders
	btn_store.pressed.connect(func(): print("Store clicked (WIP)"))
	btn_friends.pressed.connect(func(): print("Friends clicked (WIP)"))
	btn_missions.pressed.connect(func(): print("Missions clicked (WIP)"))
	btn_inventory.pressed.connect(func(): print("Inventory clicked (WIP)"))

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()

func _load_profile_data():
	# If you store the player's username/UID in GameManager or SupabaseManager, pull it here.
	var p_name = "Trailblazer"
	var p_uid = "000000000"
	
	if GameManager.player_profile.has("username"):
		p_name = GameManager.player_profile["username"]
	if GameManager.player_profile.has("uid"):
		p_uid = str(GameManager.player_profile["uid"])
		
	name_label.text = p_name
	level_uid_label.text = "Lv. 1  |  UID: " + p_uid

# --- Button Logic ---

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
	_disable_all_buttons()
	_save_current_state()
	
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _disable_all_buttons():
	btn_resume.disabled = true
	btn_quit.disabled = true
	btn_store.disabled = true
	btn_friends.disabled = true
	btn_chars.disabled = true
	btn_party.disabled = true
	btn_wish.disabled = true
	btn_missions.disabled = true
	btn_inventory.disabled = true

func _save_current_state():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_saved_position(player.global_position)
		
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path != "":
			GameManager.set_meta("return_scene", current_scene.scene_file_path)
			
	if SupabaseManager.has_method("save_current_scene_and_position"):
		SupabaseManager.save_current_scene_and_position()
