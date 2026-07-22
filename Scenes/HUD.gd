extends CanvasLayer

@onready var btn_pause = $Control/TopLeft/BtnPause
@onready var btn_chars = $Control/TopRight/HBox/BtnCharacters
@onready var btn_party = $Control/TopRight/HBox/BtnParty
@onready var btn_wish = $Control/TopRight/HBox/BtnWish

var _is_paused := false
var _is_tutorial_active := false

func _ready():
	print("HUD _ready at: ", get_path())
	print("Parent: ", get_parent())
	print("Number of children in root: ", get_tree().root.get_child_count())
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Safety: remove any orphan pause menu from previous sessions
	if get_tree().root.has_node("PauseMenu"):
		get_tree().root.get_node("PauseMenu").queue_free()

	btn_pause.pressed.connect(_on_pause_pressed)
	btn_chars.pressed.connect(_on_characters_pressed)
	btn_party.pressed.connect(_on_party_pressed)
	btn_wish.pressed.connect(_on_wish_pressed)

	TutorialManager.tutorial_visibility_changed.connect(_on_tutorial_visibility_changed)
	_update_visibility()

	print("HUD Loaded: All buttons connected successfully.")
	if get_parent() == get_tree().root:
		print("WARNING: HUD is a child of the root! This may cause duplication.")

func _on_tutorial_visibility_changed(is_tutorial_active: bool):
	_is_tutorial_active = is_tutorial_active
	_update_visibility()

func _update_visibility():
	self.visible = not (_is_paused or _is_tutorial_active)

# ═══════════════════════════════════════════════════════
#  Keyboard Input (Escape Key) – always handled
# ═══════════════════════════════════════════════════════
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if not get_tree().root.has_node("PauseMenu"):
			_on_pause_pressed()

# ═══════════════════════════════════════════════════════
#  Button Callbacks
# ═══════════════════════════════════════════════════════

func _on_pause_pressed():
	print("HUD: Pause Button / Escape Pressed!")

	if get_tree().root.has_node("PauseMenu"):
		return

	var pause_scene = load("res://Scenes/PauseMenu.tscn")
	if pause_scene:
		var pause_instance = pause_scene.instantiate()
		pause_instance.name = "PauseMenu"
		get_tree().root.add_child(pause_instance)

		_is_paused = true
		_update_visibility()

		pause_instance.tree_exited.connect(func():
			_is_paused = false
			_update_visibility()
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
		AccountManager.set_saved_position(player.global_position)
		if GameManager.current_zone_path != "":
			GameManager.set_meta("return_scene", GameManager.current_zone_path)
			print("HUD: Saved state returning to ", GameManager.current_zone_path)

	if SupabaseManager.has_method("save_current_scene_and_position"):
		SupabaseManager.save_current_scene_and_position()
