extends CanvasLayer

@onready var btn_pause = $Control/TopLeft/BtnPause
@onready var btn_chars = $Control/TopRight/HBox/BtnCharacters
@onready var btn_party = $Control/TopRight/HBox/BtnParty
@onready var btn_wish = $Control/TopRight/HBox/BtnWish

func _ready():
	# Make sure the HUD continues to process even if the tree is paused temporarily
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	btn_pause.pressed.connect(_on_pause_pressed)
	btn_chars.pressed.connect(_on_characters_pressed)
	btn_party.pressed.connect(_on_party_pressed)
	btn_wish.pressed.connect(_on_wish_pressed)
	# Connect to the manager
	TutorialManager.tutorial_visibility_changed.connect(_on_tutorial_visibility_changed)

func _on_tutorial_visibility_changed(is_tutorial_active: bool):
	self.visible = !is_tutorial_active
	
	print("HUD Loaded: All buttons connected successfully.")

# ═══════════════════════════════════════════════════════
#  Keyboard Input (Escape Key)
# ═══════════════════════════════════════════════════════
func _input(event):
	# If Escape is pressed, the HUD is visible, and the PauseMenu isn't already open
	if event.is_action_pressed("ui_cancel") and visible:
		if not get_tree().root.has_node("PauseMenu"):
			_on_pause_pressed()

# ═══════════════════════════════════════════════════════
#  Button Callbacks
# ═══════════════════════════════════════════════════════

func _on_pause_pressed():
	print("HUD: Pause Button / Escape Pressed!")
	
	# Prevent spawning multiple pause menus
	if get_tree().root.has_node("PauseMenu"):
		return
		
	var pause_scene = load("res://Scenes/PauseMenu.tscn")
	if pause_scene:
		var pause_instance = pause_scene.instantiate()
		pause_instance.name = "PauseMenu" # Explicitly name it so we can track it
		get_tree().root.add_child(pause_instance)
		
		# Hide the HUD instantly
		self.visible = false
		
		# Listen for the PauseMenu being destroyed (closed/resumed)
		pause_instance.tree_exited.connect(func():
			self.visible = true
		)

func _on_characters_pressed():
	print("HUD: Characters Button Pressed!")
	_save_current_state()
	get_tree().change_scene_to_file("res://Scenes/CharacterDetails.tscn")

func _on_party_pressed():
	print("HUD: Party Button Pressed!")
	_save_current_state()
	get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")

func _on_wish_pressed():
	print("HUD: Wish Button Pressed!")
	_save_current_state()
	get_tree().change_scene_to_file("res://Scenes/GachaScene.tscn")

# ═══════════════════════════════════════════════════════
#  State Saving
# ═══════════════════════════════════════════════════════

func _save_current_state():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_saved_position(player.global_position)
		if GameManager.current_zone_path != "":
			GameManager.set_meta("return_scene", GameManager.current_zone_path)
			print("HUD: Saved state returning to ", GameManager.current_zone_path)
			
	if SupabaseManager.has_method("save_current_scene_and_position"):
		SupabaseManager.save_current_scene_and_position()
