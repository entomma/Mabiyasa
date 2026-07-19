extends Control

# ─── Node References ──────────────────────────────────────────────────────────
@onready var overlay: ColorRect = $Overlay
@onready var right_panel: NinePatchRect = $RightPanel

@onready var btn_resume: TextureButton = $RightPanel/Margin/VBox/BottomBar/BtnResume
@onready var btn_quit: TextureButton = $RightPanel/Margin/VBox/BottomBar/BtnQuit

@onready var btn_store: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnStore
@onready var btn_friends: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnFriends
@onready var btn_chars: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnCharacters
@onready var btn_party: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnParty
@onready var btn_wish: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnWish
@onready var btn_missions: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnMissions
@onready var btn_inventory: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnInventory
@onready var btn_settings: TextureButton = $RightPanel/Margin/VBox/GridMenu/BtnSettings

# Profile UI
@onready var name_label: Label = $RightPanel/Margin/VBox/ProfileSection/Info/NameLabel
@onready var level_uid_label: Label = $RightPanel/Margin/VBox/ProfileSection/Info/LevelUID
@onready var xp_label: Label = $RightPanel/Margin/VBox/ProfileSection/Info/XPLabel
@onready var xp_bar_fill: TextureRect = $RightPanel/Margin/VBox/ProfileSection/Info/XPBarBG/XPBarFill

# ─── State ───────────────────────────────────────────────────────────────────
var is_quitting := false

# ─── Panel width — keep in sync with offset_left in the .tscn ────────────────
const PANEL_WIDTH := 480.0

# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# --- FIX: FREE THE MOUSE WHEN PAUSED ---
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_load_profile_data()
	_connect_buttons()
	_animate_in()

# ─── Input ───────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close(func(): _unpause_and_free())

# ─── Button connections ───────────────────────────────────────────────────────
func _connect_buttons() -> void:
	btn_resume.pressed.connect(func(): _close(func(): _unpause_and_free()))
	btn_quit.pressed.connect(_on_quit_pressed)

	btn_party.pressed.connect(_on_party_pressed)
	btn_wish.pressed.connect(_on_wish_pressed)
	btn_chars.pressed.connect(_on_characters_pressed)

	# Placeholders — replace with real handlers when scenes are ready
	btn_store.pressed.connect(func(): print("Store (WIP)"))
	btn_friends.pressed.connect(func(): print("Friends (WIP)"))
	btn_missions.pressed.connect(func(): print("Missions (WIP)"))
	btn_settings.pressed.connect(func(): print("Settings (WIP)"))

# ─── Profile data ─────────────────────────────────────────────────────────────
func _load_profile_data() -> void:
	var p_name := "Trailblazer"
	var p_uid := "000000000"
	var p_level := 1
	var p_exp := 0
	var p_exp_max := 10000

	if GameManager.player_profile.has("username"):
		p_name = GameManager.player_profile["username"]
	if GameManager.player_profile.has("uid"):
		p_uid = str(GameManager.player_profile["uid"])
	if GameManager.player_profile.has("level"):
		p_level = GameManager.player_profile["level"]
	if GameManager.player_profile.has("exp"):
		p_exp = GameManager.player_profile["exp"]
	if GameManager.player_profile.has("exp_max"):
		p_exp_max = GameManager.player_profile["exp_max"]

	name_label.text = p_name
	level_uid_label.text = "Lv. %d  |  UID: %s" % [p_level, p_uid]

	var xp_ratio := clampf(float(p_exp) / float(p_exp_max), 0.0, 1.0)
	if is_instance_valid(xp_bar_fill):
		xp_bar_fill.anchor_right = xp_ratio
	if is_instance_valid(xp_label):
		xp_label.text = "EXP  %d / %d" % [p_exp, p_exp_max]

# ═════════════════════════════════════════════════════════════════════════════
#  Animations
# ═════════════════════════════════════════════════════════════════════════════

func _animate_in() -> void:
	# Start panel off-screen and overlay invisible
	right_panel.offset_left = 0.0
	overlay.color.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(right_panel, "offset_left", -PANEL_WIDTH, 0.35)
	tw.tween_property(overlay, "color:a", 0.6, 0.30)

## Slides the panel back out, then calls [callback].
func _close(callback: Callable) -> void:
	_disable_all_buttons()

	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(right_panel, "offset_left", 0.0, 0.22)
	tw.tween_property(overlay, "color:a", 0.0, 0.20)

	# Wait for the longest tween to finish before running callback
	await get_tree().create_timer(0.25).timeout
	callback.call()

# ═════════════════════════════════════════════════════════════════════════════
#  Button Handlers
# ═════════════════════════════════════════════════════════════════════════════

func _unpause_and_free() -> void:
	get_tree().paused = false
	
	# --- FIX: RE-CAPTURE THE MOUSE WHEN RESUMING ---
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	queue_free()

func _on_characters_pressed() -> void:
	_close(func():
		_save_current_state()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/CharacterDetails.tscn")
	)

func _on_party_pressed() -> void:
	_close(func():
		_save_current_state()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/PartySelect.tscn")
	)

func _on_inventory_pressed() -> void:
	_close(func():
		_save_current_state()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/InventoryUI.tscn")
	)

func _on_wish_pressed() -> void:
	_close(func():
		_save_current_state()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/GachaScene.tscn")
	)

func _on_quit_pressed() -> void:
	if is_quitting:
		return
	is_quitting = true

	_close(func():
		_save_current_state()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	)

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _disable_all_buttons() -> void:
	for btn in [btn_resume, btn_quit, btn_store, btn_friends, btn_chars,
				btn_party, btn_wish, btn_missions, btn_inventory, btn_settings]:
		btn.disabled = true

func _save_current_state() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_saved_position(player.global_position)

		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path != "":
			GameManager.set_meta("return_scene", current_scene.scene_file_path)

	if SupabaseManager.has_method("save_current_scene_and_position"):
		SupabaseManager.save_current_scene_and_position()
