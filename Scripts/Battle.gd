extends Node3D

# ─────────────────────────────────────────────
#  UI References
# ─────────────────────────────────────────────
@onready var card_panel         = $BattleUI/CardPanel
@onready var card_grid          = $BattleUI/CardPanel/CardGrid
@onready var sentence_bar       = $BattleUI/CardPanel/SentenceBar
@onready var sentence_container = $BattleUI/CardPanel/SentenceBar/SentenceContainer
@onready var submit_btn         = $BattleUI/CardPanel/SentenceBar/SubmitButton
@onready var turn_order_ui      = $BattleUI/TurnOrder
@onready var char_portraits     = $BattleUI/BottomLeft/CharPortraits
@onready var skill_buttons      = $BattleUI/BottomRight
@onready var basic_btn          = $BattleUI/BottomRight/BasicButton
@onready var skill_btn          = $BattleUI/BottomRight/SkillButton
@onready var sp_stars           = $BattleUI/BottomRight/SPStars
@onready var camera             = $Camera3D

# ── Card System ───────────────────────────────
const CARD_SCENE = preload("res://Scenes/Card.tscn")
var hand: Array = []           # Array of WordCard resources
var current_hand_nodes: Array = []
var sentence: Array = []       # Array of WordCard resources for sentence building

# ─────────────────────────────────────────────
#  Dynamic storage
# ─────────────────────────────────────────────
var ult_buttons:         Array = []
var portrait_containers: Array = []
var portrait_hp_bars:    Array = []
var portrait_hp_labels:  Array = []
var portrait_shields:    Array = []
var enemy_ui_nodes:      Array = []

# ─────────────────────────────────────────────
#  Battle state
# ─────────────────────────────────────────────
var turn_queue:           Array          = []
var current_turn_index:   int            = 0
var current_character:    CharacterData  = null
var current_skill:        SkillData      = null
var total_damage_dealt:   int            = 0
var current_sp:           int            = 3
var max_sp:               int            = 5
var enemies:              Array          = []
var is_player_turn:       bool           = true

var character_hp:      Array = []
var character_shields: Array = []

var targeted_enemy_index: int  = 0
var targeted_ally_index:  int  = 0
var is_targeting_ally:    bool = false

var selected_skill_slot: String = "basic"

var active_buffs:   Dictionary = {}
var active_debuffs: Dictionary = {}

var origin_scene: String = "res://Scenes/forest.tscn"

# ─────────────────────────────────────────────
#  Over-the-Shoulder Cinematic Camera
# ─────────────────────────────────────────────
# Camera placed far bottom-left, looking diagonally toward the enemies
var camera_default_pos:    Vector3 = Vector3(-5.0, 3.5, 9.0)
var camera_default_target: Vector3 = Vector3(1.0, 1.0, -1.0)

var camera_ally_pos:       Vector3 = Vector3(-7.0, 3.0, 6.0)
var camera_ally_target:    Vector3 = Vector3(-2.0, 1.5, 1.0)

# ── Turn locks ────────────────────────────────
var _is_processing_turn: bool = false
var _is_selecting_skill: bool = false

# ─────────────────────────────────────────────
#  Constants
# ─────────────────────────────────────────────
const CARD_COLORS = {
	"Action"   : Color(0.85, 0.35, 0.28),
	"Noun"     : Color(0.20, 0.50, 0.85),
	"Number"   : Color(0.20, 0.75, 0.40),
	"Adjective": Color(0.75, 0.50, 0.85),
	"Pronoun"  : Color(0.90, 0.60, 0.10)
}
const PENALTY_NO_AFFIX      = 0.10
const PENALTY_UNMASTERED    = 0.20
const PENALTY_WRONG_GRAMMAR = 0.20
const DEF_SCALAR            = 0.30
const SPEED_JITTER          = 0.15
const ENCOUNTER_WEIGHTS     = [15, 40, 35, 10]

const ENERGY_FROM_BASIC     = 20.0
const ENERGY_FROM_SKILL     = 30.0
const ENERGY_FROM_KILL      = 10.0
const ENERGY_FROM_HIT_TAKEN = 10.0

# ─────────────────────────────────────────────
#  3D Placement Helpers (Near Allies, Far Enemies)
# ─────────────────────────────────────────────
var floor_offset: float = 1.8 # Raised slightly for scaled up models

func _get_ally_pos(idx: int) -> Vector3:
	# ALLIES: Near the screen (Z = 4.5). They trail backwards and to the left.
	return Vector3(-3.0 - (idx * 1.5), floor_offset, 4.5 - (idx * 1.0))

func _get_enemy_pos(idx: int) -> Vector3:
	# ENEMIES: Far from screen (Z = -2.0). They start deep right and slant forward slightly.
	return Vector3(2.5 + (idx * 3), floor_offset, -2.2 + (idx * 1.0))

# ─────────────────────────────────────────────
#  _ready
# ─────────────────────────────────────────────
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	card_panel.visible = false
	skill_buttons.visible = false
	
	print("🌍 Battle Scene: Stabilizing Yugen Terrain...")

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw

	var terrain = find_child("MarchingSquaresTerrain", true, false)
	if terrain:
		print("✓ Terrain found - starting hard reset")
		
		terrain.set_process(false)
		terrain.set_physics_process(false)
		terrain.visible = false
		
		if terrain.has_method("clear_cache"): terrain.call("clear_cache")
		if terrain.has_method("reset"): terrain.call("reset")
		if terrain.has_method("free_chunks"): terrain.call("free_chunks")

		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		
		terrain.visible = true
		terrain.set_process(true)
		terrain.set_physics_process(true)
		
		await get_tree().create_timer(0.1).timeout
		
		if terrain.has_method("force_update"): terrain.call("force_update")
		elif terrain.has_method("update_terrain"): terrain.call("update_terrain")
		elif terrain.has_method("generate"): terrain.call("generate")
		
		await RenderingServer.frame_post_draw
		print("✓ Terrain FULLY stabilized")

	var transition = get_tree().get_first_node_in_group("transition")
	if transition: transition.fade_in()

	if GameManager.has_meta("last_scene"):
		origin_scene = GameManager.get_meta("last_scene")

	_init_character_hp()

	basic_btn.pressed.connect(_on_basic_btn_pressed)
	skill_btn.pressed.connect(_on_skill_btn_pressed)
	submit_btn.pressed.connect(_on_submit_pressed)

	_style_circular_button(basic_btn, Color(0.72, 0.58, 0.42))
	_style_circular_button(skill_btn, Color(0.85, 0.35, 0.28))

	var old_dmg_panel = get_node_or_null("BattleUI/TotalDamage")
	if old_dmg_panel: old_dmg_panel.visible = false

	_setup_card_panel_bg()
	_spawn_enemies_for_zone()
	_build_turn_queue()
	_setup_character_portraits()
	_setup_battle_sprites()
	draw_hand()
	start_battle()

	if camera:
		camera.position = camera_default_pos
		camera.look_at(camera_default_target, Vector3.UP)

func _init_character_hp():
	character_hp.clear()
	character_shields.clear()
	for character in GameManager.player_party:
		character_hp.append(float(character.get_actual_hp()))
		character_shields.append(0.0)

# ─────────────────────────────────────────────
#  Card System Functions
# ─────────────────────────────────────────────
func draw_hand():
	for card_node in current_hand_nodes:
		if is_instance_valid(card_node):
			card_node.queue_free()
	current_hand_nodes.clear()
	hand.clear()
	
	var all_cards = []
	var dir = DirAccess.open("res://Resources/Cards/")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".tres"):
				var card = load("res://Resources/Cards/" + f)
				if card is WordCard:
					all_cards.append(card)
	
	var has_action = false
	var has_noun = false
	var has_pronoun = false
	
	for card in all_cards:
		match card.card_type:
			"Action": has_action = true
			"Noun": has_noun = true
			"Pronoun": has_pronoun = true
	
	if not has_action:
		var default_action = WordCard.new()
		default_action.kapampangan_text = "Gawa"
		default_action.english_hint = "Do/Action"
		default_action.card_type = "Action"
		all_cards.append(default_action)
	
	if not has_noun:
		var default_noun = WordCard.new()
		default_noun.kapampangan_text = "Bagay"
		default_noun.english_hint = "Thing/Noun"
		default_noun.card_type = "Noun"
		all_cards.append(default_noun)
	
	if not has_pronoun:
		var default_pronoun = WordCard.new()
		default_pronoun.kapampangan_text = "Aku"
		default_pronoun.english_hint = "I/Me"
		default_pronoun.card_type = "Pronoun"
		all_cards.append(default_pronoun)
	
	all_cards.shuffle()
	
	for i in range(min(7, all_cards.size())):
		var card_data = all_cards[i]
		hand.append(card_data)
		var card_node = CARD_SCENE.instantiate()
		card_node.card_data = card_data
		card_grid.add_child(card_node)
		current_hand_nodes.append(card_node)
		card_node.card_selected.connect(_on_card_toggled)

	update_sentence_display()

func _on_card_toggled(card_data: WordCard):
	if _is_processing_turn or _is_selecting_skill:
		return
	
	if sentence.has(card_data):
		sentence.erase(card_data)
	else:
		sentence.append(card_data)
	
	for card_node in current_hand_nodes:
		if card_node.card_data == card_data:
			card_node.set_highlight(sentence.has(card_data))
	
	update_sentence_display()

func update_sentence_display():
	for child in sentence_container.get_children():
		child.queue_free()
	
	if sentence.size() == 0:
		var ph = Label.new()
		ph.text = "Select cards to build your sentence..."
		ph.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		sentence_container.add_child(ph)
		return
	
	for card in sentence:
		var pill = PanelContainer.new()
		var s = StyleBoxFlat.new()
		s.bg_color = CARD_COLORS.get(card.card_type, Color(0.5, 0.5, 0.5))
		for c in ["top_left","top_right","bottom_left","bottom_right"]:
			s.set("corner_radius_"+c, 20)
		s.border_width_bottom = 2
		s.border_color = s.bg_color.darkened(0.3)
		pill.add_theme_stylebox_override("panel", s)
		
		var lbl = Label.new()
		lbl.text = card.kapampangan_text
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 16)
		pill.add_child(lbl)
		
		var btn = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(func(): 
			sentence.erase(card)
			update_sentence_display()
			for card_node in current_hand_nodes:
				if card_node.card_data == card:
					card_node.set_highlight(false)
		)
		pill.add_child(btn)
		sentence_container.add_child(pill)

# ─────────────────────────────────────────────
#  Input
# ─────────────────────────────────────────────
func _input(event: InputEvent):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not is_player_turn:
		return

	if is_targeting_ally:
		match event.keycode:
			KEY_A: _navigate_ally(-1)
			KEY_D: _navigate_ally(1)
			KEY_ENTER, KEY_SPACE: _confirm_ally_target()
		return

	if card_panel.visible:
		return

	match event.keycode:
		KEY_Q:
			if selected_skill_slot == "basic": _activate_selected_skill()
			else:
				selected_skill_slot = "basic"
				_refresh_skill_highlights()
		KEY_E:
			if selected_skill_slot == "skill": _activate_selected_skill()
			else:
				selected_skill_slot = "skill"
				_refresh_skill_highlights()
		KEY_1: _trigger_ult(0)
		KEY_2: _trigger_ult(1)
		KEY_3: _trigger_ult(2)
		KEY_4: _trigger_ult(3)
		KEY_A: _navigate_enemy(-1)
		KEY_D: _navigate_enemy(1)

# ─────────────────────────────────────────────
#  Enemy targeting
# ─────────────────────────────────────────────
func _navigate_enemy(dir: int):
	targeted_enemy_index = clamp(targeted_enemy_index + dir, 0, enemies.size() - 1)
	_refresh_enemy_highlight()

func _refresh_enemy_highlight():
	for i in range(enemy_ui_nodes.size()):
		var ui = enemy_ui_nodes[i]
		if not ui or not is_instance_valid(ui.root): continue
		ui.root.modulate = Color(1.3, 1.3, 0.6) if i == targeted_enemy_index else Color(1,1,1)

func _set_enemy_target(idx: int):
	targeted_enemy_index = clamp(idx, 0, enemies.size() - 1)
	_refresh_enemy_highlight()

# ─────────────────────────────────────────────
#  Ally targeting
# ─────────────────────────────────────────────
func _begin_ally_targeting():
	_is_selecting_skill = false
	is_targeting_ally   = true
	targeted_ally_index = _index_of_current_char()
	_refresh_ally_highlight()
	_pan_camera_to_allies()

func _navigate_ally(dir: int):
	targeted_ally_index = clamp(targeted_ally_index + dir, 0, GameManager.player_party.size() - 1)
	_refresh_ally_highlight()

func _confirm_ally_target():
	is_targeting_ally = false
	_refresh_ally_highlight()
	_pan_camera_to_default()
	show_card_panel()

func _refresh_ally_highlight():
	for i in range(portrait_containers.size()):
		portrait_containers[i].modulate = \
			Color(1.3, 1.3, 0.6) if i == targeted_ally_index else Color(1,1,1)

func _index_of_current_char() -> int:
	for i in range(GameManager.player_party.size()):
		if GameManager.player_party[i] == current_character:
			return i
	return 0

func _pan_camera_to_allies():
	if not camera: return
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(camera, "position", camera_ally_pos, 0.4)
	t.tween_method(func(v): camera.look_at(v, Vector3.UP),
		camera_default_target, camera_ally_target, 0.4)

func _pan_camera_to_default():
	if not camera: return
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(camera, "position", camera_default_pos, 0.4)
	t.tween_method(func(v): camera.look_at(v, Vector3.UP),
		camera_ally_target, camera_default_target, 0.4)

# ─────────────────────────────────────────────
#  Skill slot selection (Restored UI Shadows)
# ─────────────────────────────────────────────
func _activate_selected_skill():
	match selected_skill_slot:
		"basic": _on_basic_pressed()
		"skill": _on_skill_pressed()

func _refresh_skill_highlights():
	_restyle_slot_btn(basic_btn, Color(0.72, 0.58, 0.42), selected_skill_slot == "basic")
	_restyle_slot_btn(skill_btn, Color(0.85, 0.35, 0.28), selected_skill_slot == "skill")

func _restyle_slot_btn(btn: Button, color: Color, active: bool):
	btn.custom_minimum_size = Vector2(180, 180) if active else Vector2(130, 130)
	var s = StyleBoxFlat.new()
	s.bg_color = color if active else color.darkened(0.45)
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		s.set("corner_radius_" + c, 999)
	var bw = 3 if active else 1
	s.border_width_left = bw; s.border_width_right = bw; s.border_width_top = bw; s.border_width_bottom = bw
	s.border_color = color.lightened(0.5) if active else color.darkened(0.2)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 8 if active else 3
	s.shadow_offset = Vector2(0, 4) if active else Vector2(0, 2)
	btn.add_theme_stylebox_override("normal", s)
	
	var h = StyleBoxFlat.new()
	h.bg_color = color.lightened(0.2)
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		h.set("corner_radius_" + c, 999)
	h.border_width_left = 3; h.border_width_right = 3; h.border_width_top = 3; h.border_width_bottom = 3
	h.border_color = color.lightened(0.8)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_font_size_override("font_size", 16 if active else 13)

func _trigger_ult(idx: int):
	if _is_selecting_skill or _is_processing_turn: return
	if idx >= GameManager.player_party.size(): return
	var cd = GameManager.player_party[idx]
	if cd.ultimate == null: return
	if not cd.is_ult_ready():
		print("Ult not ready for ", cd.character_name)
		return
	_is_selecting_skill = true
	current_character   = cd
	current_skill       = cd.ultimate as SkillData
	_decide_targeting()

# ─────────────────────────────────────────────
#  Targeting decision
# ─────────────────────────────────────────────
func _decide_targeting():
	if current_skill == null: return
	if current_skill.is_aoe() or current_skill.target_type == "Self":
		show_card_panel()
	elif current_skill.targets_ally() and current_skill.target_type == "Single":
		_begin_ally_targeting()
	else:
		show_card_panel()

# ─────────────────────────────────────────────
#  Zone enemy spawning
# ─────────────────────────────────────────────
func _spawn_enemies_for_zone():
	enemies.clear()
	var pool = _get_enemy_pool()
	if pool.is_empty():
		if GameManager.active_enemy_data: pool = [GameManager.active_enemy_data]
		else: push_error("No enemy pool!"); return

	var count = _weighted_count()
	pool.shuffle()
	for i in range(count):
		var data: EnemyData = pool[i % pool.size()]
		var spd = int(data.speed * (1.0 + randf_range(-SPEED_JITTER, SPEED_JITTER)))
		enemies.append({
			"data":              data,
			"current_hp":        data.get_actual_hp(),
			"current_shield_hp": data.get_actual_shield_hp(),
			"is_shield_active":  data.is_shield_active,
			"speed":             spd,
			"index":             i
		})
	print("Spawned ", enemies.size(), " enemies")

func _get_enemy_pool() -> Array:
	var pools = {
		"res://Scenes/Zone1.tscn": [
			load("res://Resources/Enemies/kalapati.tres"),
			load("res://Resources/Enemies/dagis.tres")
		],
		"res://Scenes/HubTown.tscn": [
			load("res://Resources/Enemies/dagis.tres")
		]
	}
	if pools.has(origin_scene): return pools[origin_scene]
	var fallback = []
	var dir = DirAccess.open("res://Resources/Enemies/")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".tres"): fallback.append(load("res://Resources/Enemies/" + f))
	return fallback

func _weighted_count() -> int:
	var total = 0
	for w in ENCOUNTER_WEIGHTS: total += w
	var roll = randi() % total
	var cum  = 0
	for i in range(ENCOUNTER_WEIGHTS.size()):
		cum += ENCOUNTER_WEIGHTS[i]
		if roll < cum: return i + 1
	return 2

# ─────────────────────────────────────────────
#  Turn queue
# ─────────────────────────────────────────────
func _build_turn_queue():
	turn_queue.clear()
	for character in GameManager.player_party:
		var spd = int(character.speed * (1.0 + randf_range(-SPEED_JITTER, SPEED_JITTER)))
		turn_queue.append({"type": "player", "data": character, "speed": spd})
	for enemy in enemies:
		turn_queue.append({"type": "enemy", "data": enemy, "speed": enemy.speed})
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)

# ─────────────────────────────────────────────
#  Enemy HP / Shield UI
# ─────────────────────────────────────────────
func _build_enemy_ui():
	for ui in enemy_ui_nodes:
		if ui and is_instance_valid(ui.root): ui.root.queue_free()
	enemy_ui_nodes.clear()

	for i in range(enemies.size()):
		var enemy = enemies[i]
		var w_pos = _get_enemy_pos(i)

		var root = Control.new()
		root.name = "EnemyUI_" + str(i)
		root.custom_minimum_size = Vector2(160, 64)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$BattleUI.add_child(root)

		var shield_bar = ProgressBar.new()
		shield_bar.custom_minimum_size = Vector2(150, 7)
		shield_bar.max_value    = float(max(1, enemy.data.get_actual_shield_hp()))
		shield_bar.value        = float(enemy.current_shield_hp)
		shield_bar.show_percentage = false
		shield_bar.visible      = enemy.is_shield_active
		shield_bar.position     = Vector2(5, 0)
		_style_bar(shield_bar, Color(0.4, 0.7, 1.0), Color(0.1, 0.2, 0.4))
		root.add_child(shield_bar)

		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(150, 11)
		hp_bar.max_value    = float(enemy.data.get_actual_hp())
		hp_bar.value        = float(enemy.current_hp)
		hp_bar.show_percentage = false
		hp_bar.position     = Vector2(5, 9)
		_style_bar(hp_bar, Color(0.2, 0.85, 0.35), Color(0.1, 0.25, 0.1))
		root.add_child(hp_bar)

		var hp_lbl = Label.new()
		hp_lbl.text = _hp_text(enemy.current_hp, enemy.data.get_actual_hp())
		hp_lbl.add_theme_font_size_override("font_size", 10)
		hp_lbl.add_theme_color_override("font_color", Color.WHITE)
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.position = Vector2(5, 22)
		hp_lbl.size     = Vector2(150, 14)
		hp_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
		hp_lbl.add_theme_constant_override("shadow_offset_x", 1)
		hp_lbl.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(hp_lbl)

		var name_lbl = Label.new()
		name_lbl.text = enemy.data.enemy_name
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(5, 38)
		name_lbl.size     = Vector2(150, 14)
		name_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
		root.add_child(name_lbl)

		var btn = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(func(): _set_enemy_target(i))
		root.add_child(btn)

		enemy_ui_nodes.append({
			"root":       root,
			"hp_bar":     hp_bar,
			"shield_bar": shield_bar,
			"hp_label":   hp_lbl,
			"world_pos":  w_pos
		})

func _style_bar(bar: ProgressBar, fill: Color, bg: Color):
	var sf = StyleBoxFlat.new()
	sf.bg_color = fill
	for c in ["top_left","top_right","bottom_left","bottom_right"]: sf.set("corner_radius_"+c, 4)
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	for c in ["top_left","top_right","bottom_left","bottom_right"]: sb.set("corner_radius_"+c, 4)
	sb.border_width_left = 1; sb.border_width_right = 1; sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.05, 0.05, 0.05, 0.8)
	bar.add_theme_stylebox_override("fill", sf)
	bar.add_theme_stylebox_override("background", sb)

func _hp_text(current: float, maximum: int) -> String:
	return str(max(0, int(current))) + "/" + str(maximum)

func _process(_delta):
	if not camera: return
	for i in range(enemy_ui_nodes.size()):
		var ui = enemy_ui_nodes[i]
		if not ui or not is_instance_valid(ui.root): continue
		# Unproject dynamically with added height for scaled models
		var sp = camera.unproject_position(ui.world_pos + Vector3(0, 2.8, 0))
		ui.root.position = sp - Vector2(75, 0)

func _update_enemy_ui(idx: int):
	if idx >= enemy_ui_nodes.size() or idx >= enemies.size(): return
	var ui    = enemy_ui_nodes[idx]
	var enemy = enemies[idx]
	if not ui or not is_instance_valid(ui.root): return
	ui.hp_bar.value  = float(max(0, enemy.current_hp))
	ui.hp_label.text = _hp_text(enemy.current_hp, enemy.data.get_actual_hp())
	ui.shield_bar.visible = enemy.is_shield_active
	if enemy.is_shield_active:
		ui.shield_bar.value = float(enemy.current_shield_hp)

func _shatter_shield(idx: int):
	if idx >= enemy_ui_nodes.size(): return
	var ui = enemy_ui_nodes[idx]
	if not ui or not is_instance_valid(ui.root): return
	var sb = ui.shield_bar
	var t  = create_tween()
	t.tween_property(sb, "modulate", Color(2,2,2),   0.05)
	t.tween_property(sb, "modulate", Color(1,1,1),   0.05)
	t.tween_property(sb, "modulate", Color(2,2,2),   0.05)
	t.tween_property(sb, "modulate", Color(0,0,0,0), 0.15)
	await t.finished
	sb.visible  = false
	sb.modulate = Color(1,1,1,1)
	var sprite = $Background.get_node_or_null("enemy_sprite_" + str(idx))
	if sprite:
		var st = create_tween()
		st.tween_property(sprite, "modulate", Color(3,3,1), 0.05)
		st.tween_property(sprite, "modulate", Color(1,1,1), 0.25)

# ─────────────────────────────────────────────
#  Character portrait HP + shield (Restored UI Shadows)
# ─────────────────────────────────────────────
func _update_portrait_hp(char_idx: int):
	if char_idx >= GameManager.player_party.size(): return
	var cd     = GameManager.player_party[char_idx]
	var max_hp = float(cd.get_actual_hp())
	var cur_hp = character_hp[char_idx]
	var shield = character_shields[char_idx]

	if char_idx < portrait_hp_bars.size() and is_instance_valid(portrait_hp_bars[char_idx]):
		portrait_hp_bars[char_idx].value = max(0.0, cur_hp)

	if char_idx < portrait_hp_labels.size() and is_instance_valid(portrait_hp_labels[char_idx]):
		portrait_hp_labels[char_idx].text = _hp_text(cur_hp, int(max_hp))

	if char_idx < portrait_shields.size() and is_instance_valid(portrait_shields[char_idx]):
		var shield_rect = portrait_shields[char_idx]
		if shield > 0.0:
			shield_rect.visible = true
			shield_rect.size.x  = 90.0 * clamp(shield / max_hp, 0.0, 1.0)
		else:
			shield_rect.visible = false

func _update_energy_display(char_idx: int):
	if char_idx >= GameManager.player_party.size(): return
	if char_idx >= ult_buttons.size(): return
	var cd  = GameManager.player_party[char_idx]
	var btn = ult_buttons[char_idx]
	var pct = cd.current_energy / cd.max_energy
	btn.text = "[" + str(char_idx + 1) + "] ULT\n" + str(int(pct * 100)) + "%"
	if cd.is_ult_ready():
		btn.disabled = false
		btn.modulate = Color(1, 1, 1)
	else:
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5)

# ─────────────────────────────────────────────
#  Energy
# ─────────────────────────────────────────────
func _give_energy_action(char_data: CharacterData, base_amount: float):
	char_data.gain_energy(base_amount, true)
	var idx = GameManager.player_party.find(char_data)
	if idx >= 0: _update_energy_display(idx)

func _give_energy_hit_taken(char_data: CharacterData):
	char_data.gain_energy(ENERGY_FROM_HIT_TAKEN, false)
	var idx = GameManager.player_party.find(char_data)
	if idx >= 0: _update_energy_display(idx)

# ─────────────────────────────────────────────
#  Setup helpers
# ─────────────────────────────────────────────
func _setup_card_panel_bg():
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	for c in ["top_left","top_right","bottom_left","bottom_right"]: s.set("corner_radius_"+c, 16)
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.border_color = Color(0.3, 0.3, 0.4, 0.5)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	card_panel.add_theme_stylebox_override("panel", s)

func _setup_character_portraits():
	for child in char_portraits.get_children(): child.queue_free()
	ult_buttons.clear()
	portrait_containers.clear()
	portrait_hp_bars.clear()
	portrait_hp_labels.clear()
	portrait_shields.clear()

	for i in range(GameManager.player_party.size()):
		var cd: CharacterData = GameManager.player_party[i]
		
		var panel = PanelContainer.new()
		var ps = StyleBoxFlat.new()
		ps.bg_color = Color(0.05, 0.05, 0.08, 0.8) 
		ps.set_corner_radius_all(12)
		ps.content_margin_left = 6; ps.content_margin_right = 6; 
		ps.content_margin_top = 8; ps.content_margin_bottom = 8;
		panel.add_theme_stylebox_override("panel", ps)
		
		var box = VBoxContainer.new()
		box.name = "Portrait" + str(i+1)
		box.custom_minimum_size = Vector2(100, 185)

		var img = TextureRect.new()
		img.custom_minimum_size   = Vector2(80, 80)
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if cd.splash_art:
			img.texture      = cd.splash_art
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		box.add_child(img)

		var name_lbl = Label.new()
		name_lbl.text = cd.character_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		box.add_child(name_lbl)

		var bar_container = Control.new()
		bar_container.custom_minimum_size  = Vector2(90, 14)
		bar_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var hp_bar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_bar.max_value       = float(cd.get_actual_hp())
		hp_bar.value           = float(cd.get_actual_hp())
		hp_bar.show_percentage = false
		_style_bar(hp_bar, Color(0.2,0.85,0.35), Color(0.1,0.25,0.1))
		bar_container.add_child(hp_bar)

		var shield_rect = ColorRect.new()
		shield_rect.name         = "ShieldRect"
		shield_rect.color        = Color(0.4, 0.7, 1.0, 0.6)
		shield_rect.visible      = false
		shield_rect.position     = Vector2(0, 0)
		shield_rect.size         = Vector2(0, 14)
		shield_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_container.add_child(shield_rect)

		box.add_child(bar_container)
		portrait_hp_bars.append(hp_bar)
		portrait_shields.append(shield_rect)

		var hp_lbl = Label.new()
		hp_lbl.name = "HPLabel"
		hp_lbl.text = _hp_text(float(cd.get_actual_hp()), cd.get_actual_hp())
		hp_lbl.add_theme_font_size_override("font_size", 9)
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_color_override("font_color", Color(0.8,1.0,0.8))
		box.add_child(hp_lbl)
		portrait_hp_labels.append(hp_lbl)

		var ult = Button.new()
		ult.name = "UltButton"
		ult.text = "[" + str(i+1) + "] ULT\n" + str(int((cd.current_energy / cd.max_energy) * 100)) + "%"
		ult.custom_minimum_size   = Vector2(90, 32)
		ult.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ult.disabled              = not cd.is_ult_ready()
		ult.modulate              = Color(1,1,1) if cd.is_ult_ready() else Color(0.5,0.5,0.5)
		_style_ult_button(ult)
		ult.pressed.connect(_trigger_ult.bind(i))
		box.add_child(ult)

		ult_buttons.append(ult)
		panel.add_child(box)
		portrait_containers.append(panel)
		char_portraits.add_child(panel)

func _style_ult_button(btn: Button):
	for state in ["normal","hover","disabled"]:
		var s = StyleBoxFlat.new()
		match state:
			"normal":   s.bg_color = Color(0.65, 0.2, 0.8)
			"hover":    s.bg_color = Color(0.85, 0.4, 1.0)
			"disabled": s.bg_color = Color(0.25, 0.1, 0.3)
		for c in ["top_left","top_right","bottom_left","bottom_right"]: s.set("corner_radius_"+c, 14)
		s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
		s.border_color = Color(0.9, 0.6, 1.0) if state != "disabled" else Color(0.4, 0.2, 0.5)
		s.shadow_color = Color(0,0,0,0.4)
		s.shadow_size = 2
		s.shadow_offset = Vector2(0, 1)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 11)

func _style_circular_button(btn: Button, color: Color):
	for state in ["normal","hover"]:
		var s = StyleBoxFlat.new()
		s.bg_color = color.lightened(0.2) if state == "hover" else color
		for c in ["top_left","top_right","bottom_left","bottom_right"]: s.set("corner_radius_"+c, 999)
		s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
		s.border_color = color.lightened(0.4)
		s.shadow_color = Color(0,0,0,0.3)
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 3)
		btn.add_theme_stylebox_override(state, s)

# ─────────────────────────────────────────────
#  Turn flow
# ─────────────────────────────────────────────
func start_battle():
	current_turn_index   = 0
	selected_skill_slot  = "basic"
	targeted_enemy_index = 0
	_is_processing_turn  = false
	_is_selecting_skill  = false
	process_next_turn()

func process_next_turn():
	if turn_queue.size() == 0: return

	turn_queue = turn_queue.filter(func(t):
		if t.type == "enemy": return enemies.has(t.data)
		return true
	)
	if turn_queue.size() == 0: return
	if current_turn_index >= turn_queue.size(): current_turn_index = 0

	_tick_status_effects()
	update_turn_order_ui()

	var current = turn_queue[current_turn_index]
	if current.type == "player":
		current_character   = current.data
		is_player_turn      = true
		selected_skill_slot = "basic"
		show_skill_buttons()
	else:
		is_player_turn = false
		await enemy_turn(current.data)

func show_skill_buttons():
	_is_selecting_skill   = false
	_is_processing_turn   = false
	submit_btn.disabled   = false
	skill_buttons.visible = true
	card_panel.visible    = false
	is_targeting_ally     = false

	var bd = current_character.basic_attack as SkillData
	var sd = current_character.skill as SkillData
	if bd == null or sd == null:
		push_error("Missing skills: " + current_character.character_name)
		return

	basic_btn.text     = "[Q] Basic\n(+" + str(bd.sp_gain) + " SP)"
	skill_btn.text     = "[E] Skill\n(-" + str(sd.sp_cost) + " SP)"
	skill_btn.disabled = current_sp < sd.sp_cost

	for i in range(ult_buttons.size()):
		_update_energy_display(i)

	for i in range(portrait_containers.size()):
		portrait_containers[i].modulate = \
			Color(1.2,1.2,1.2) if GameManager.player_party[i] == current_character \
			else Color(1,1,1)

	_refresh_skill_highlights()
	_update_sp_display()
	_refresh_enemy_highlight()

# ─────────────────────────────────────────────
#  Button callbacks
# ─────────────────────────────────────────────
func _on_basic_btn_pressed():
	if _is_selecting_skill or _is_processing_turn: return
	if selected_skill_slot == "basic": _on_basic_pressed()
	else:
		selected_skill_slot = "basic"
		_refresh_skill_highlights()

func _on_skill_btn_pressed():
	if _is_selecting_skill or _is_processing_turn: return
	if selected_skill_slot == "skill": _on_skill_pressed()
	else:
		selected_skill_slot = "skill"
		_refresh_skill_highlights()

func _on_basic_pressed():
	if _is_selecting_skill or _is_processing_turn: return
	if current_character.basic_attack == null: return
	_is_selecting_skill = true
	current_skill = current_character.basic_attack as SkillData
	_decide_targeting()

func _on_skill_pressed():
	if _is_selecting_skill or _is_processing_turn: return
	var sd = current_character.skill as SkillData
	if sd == null or current_sp < sd.sp_cost:
		print("Not enough SP!")
		return
	_is_selecting_skill = true
	current_skill = sd
	_decide_targeting()

func show_card_panel():
	_is_selecting_skill   = false
	skill_buttons.visible = false
	card_panel.visible    = true
	sentence_bar.visible  = true

# ─────────────────────────────────────────────
#  Submit with sentence building
# ─────────────────────────────────────────────
func _on_submit_pressed():
	if _is_processing_turn: return
	if sentence.size() == 0 or (enemies.size() == 0 and not current_skill.targets_ally()):
		return
	
	_is_processing_turn = true
	submit_btn.disabled = true

	var quality = analyse_sentence_quality()
	var raw_damage = calculate_damage(quality)
	var turn_damage = 0

	if current_skill.is_damage_skill():
		if current_skill.is_aoe():
			for i in range(enemies.size()):
				turn_damage += await deal_damage(raw_damage, i)
		else:
			turn_damage = await deal_damage(raw_damage, targeted_enemy_index)

	resolve_skill_effects()

	var stype = current_skill.skill_type.to_lower() if current_skill.skill_type else ""
	match stype:
		"basic":
			current_sp = min(current_sp + current_skill.sp_gain, max_sp)
			_give_energy_action(current_character, ENERGY_FROM_BASIC)
		"skill":
			current_sp = max(0, current_sp - current_skill.sp_cost)
			_give_energy_action(current_character, ENERGY_FROM_SKILL)
		"ultimate":
			current_character.consume_energy()
			_update_energy_display(_index_of_current_char())

	_update_sp_display()

	if turn_damage > 0:
		_show_turn_damage(turn_damage)

	await get_tree().create_timer(0.5).timeout
	show_feedback_popup(turn_damage, quality)

	for card in sentence:
		hand.erase(card)
	sentence.clear()

	draw_hand()

	current_turn_index += 1
	await get_tree().create_timer(1.5).timeout
	card_panel.visible = false
	_pan_camera_to_default()

	_is_processing_turn = false
	submit_btn.disabled = false
	process_next_turn()

# ─────────────────────────────────────────────
#  Sentence quality analysis
# ─────────────────────────────────────────────
func analyse_sentence_quality() -> Dictionary:
	var r = {
		"grammar_ok": false,
		"focus_type": "",
		"word_order_ok": false,
		"has_affix": false,
		"all_mastered": true,
		"grammar_penalty": 0.0,
		"affix_penalty": 0.0,
		"mastery_penalty": 0.0,
		"total_multiplier": 1.0,
		"feedback_lines": [],
		"example_sentence": ""
	}

	var cards_by_type = {"Action": [], "Noun": [], "Pronoun": [], "Adjective": [], "Number": []}
	for card in sentence:
		var t = card.card_type
		if cards_by_type.has(t): cards_by_type[t].append(card)

	var has_action  = cards_by_type["Action"].size() > 0
	var has_noun    = cards_by_type["Noun"].size() > 0
	var has_pronoun = cards_by_type["Pronoun"].size() > 0

	r.word_order_ok = sentence.size() > 0 and sentence[0].card_type == "Action"

	var min_cards = 2
	var stype = current_skill.skill_type.to_lower() if current_skill.skill_type else ""
	if stype == "skill":    min_cards = 3
	elif stype == "ultimate": min_cards = 4

	var is_actor_focus  = false
	var is_object_focus = false

	if r.word_order_ok and sentence.size() >= 2:
		if sentence.size() >= 3:
			is_actor_focus = (
				sentence[0].card_type == "Action" and
				sentence[1].card_type == "Pronoun" and
				has_noun
			)
			is_object_focus = (
				sentence[0].card_type == "Action" and
				sentence[1].card_type == "Noun" and
				has_pronoun
			)
		elif sentence.size() == 2:
			is_actor_focus  = (sentence[0].card_type == "Action" and has_noun)
			is_object_focus = (sentence[0].card_type == "Action" and has_noun)

	r.grammar_ok = (is_actor_focus or is_object_focus) and sentence.size() >= min_cards
	if is_actor_focus:    r.focus_type = "Actor"
	elif is_object_focus: r.focus_type = "Object"

	var verb_text    = cards_by_type["Action"][0].kapampangan_text  if has_action  else "Verb"
	var noun_text    = cards_by_type["Noun"][0].kapampangan_text    if has_noun    else "Noun"
	var pronoun_text = cards_by_type["Pronoun"][0].kapampangan_text if has_pronoun else "Aku"

	match stype:
		"basic":
			r.example_sentence = verb_text + " " + noun_text
		"skill":
			r.example_sentence = verb_text + " " + pronoun_text + " " + noun_text + \
				"\n(Actor) or: " + verb_text + " " + noun_text + " " + pronoun_text + " (Object)"
		"ultimate":
			r.example_sentence = verb_text + " " + pronoun_text + " " + noun_text + " [+1 more card]"

	if not r.word_order_ok:
		r.grammar_penalty = PENALTY_WRONG_GRAMMAR
		r.feedback_lines.append({"text": "✗ Verb must come FIRST!", "color": Color(1.0, 0.35, 0.35)})
		r.feedback_lines.append({"text": "→ " + r.example_sentence, "color": Color(0.9, 0.9, 0.5)})
	elif not r.grammar_ok:
		r.grammar_penalty = PENALTY_WRONG_GRAMMAR
		if sentence.size() < min_cards:
			r.feedback_lines.append({"text": "✗ Need " + str(min_cards) + " cards minimum!", "color": Color(1.0, 0.35, 0.35)})
		elif not has_noun and stype != "basic":
			r.feedback_lines.append({"text": "✗ Missing a Noun!", "color": Color(1.0, 0.35, 0.35)})
		elif not has_pronoun and min_cards >= 3:
			r.feedback_lines.append({"text": "✗ Missing a Pronoun (Aku/Ika/Ya)!", "color": Color(1.0, 0.35, 0.35)})
		else:
			r.feedback_lines.append({"text": "✗ Wrong sentence structure!", "color": Color(1.0, 0.35, 0.35)})
		r.feedback_lines.append({"text": "→ Try: " + r.example_sentence, "color": Color(0.9, 0.9, 0.5)})
	else:
		match r.focus_type:
			"Actor":
				r.feedback_lines.append({"text": "✓ Actor Focus! (Verb + Pronoun + Noun)", "color": Color(0.35, 1.0, 0.5)})
			"Object":
				r.feedback_lines.append({"text": "✓ Object Focus! (Verb + Noun + Pronoun)", "color": Color(0.35, 1.0, 0.5)})

	for card in sentence:
		if card.category in ["Affix", "Prefix", "Suffix", "Connector"]:
			r.has_affix = true
			break
	
	if not r.has_affix:
		r.affix_penalty = PENALTY_NO_AFFIX
		r.feedback_lines.append({"text": "No affixes  −10% DMG", "color": Color(1.0, 0.65, 0.2)})
	else:
		r.feedback_lines.append({"text": "✓ Affixes used!", "color": Color(0.35, 1.0, 0.5)})

	r.total_multiplier = max(0.40, 1.0 - r.grammar_penalty - r.affix_penalty - r.mastery_penalty)
	return r

# ─────────────────────────────────────────────
#  Damage calculation
# ─────────────────────────────────────────────
func calculate_damage(quality: Dictionary) -> int:
	if not current_skill.is_damage_skill(): return 0
	var raw = int(current_character.get_actual_attack() * current_skill.get_actual_multiplier())

	var talent = current_character.talent as SkillData
	if talent and talent.trigger_effect == "DamageBoost":
		for card in sentence:
			if card.category == talent.trigger_card_category or card.card_type == talent.trigger_card_type:
				raw = int(raw * (1.0 + talent.trigger_value))
				break

	if active_buffs.has(current_character):
		raw = int(raw * (1.0 + active_buffs[current_character].get("atk_bonus", 0.0)))

	if current_skill.element == current_character.element:
		raw = int(raw * (1.0 + current_character.elemental_bonus))

	raw = int(raw * quality.total_multiplier)

	if randf() < current_character.crit_rate:
		raw = int(raw * current_character.crit_damage)
		print("CRITICAL!")

	return raw

# ─────────────────────────────────────────────
#  Deal damage
# ─────────────────────────────────────────────
func deal_damage(raw: int, idx: int) -> int:
	if idx >= enemies.size() or raw <= 0: return 0
	var target = enemies[idx]

	var def_red = active_debuffs.get(target, {}).get("def_reduction", 0.0)
	var eff_def = int(target.data.get_actual_defense() * (1.0 - def_red))
	var actual  = max(1, raw - int(eff_def * DEF_SCALAR))
	var dealt   = 0

	if target.is_shield_active:
		if current_skill.element == target.data.shield_element:
			target.current_shield_hp -= actual
			if target.current_shield_hp <= 0:
				var overflow             = abs(target.current_shield_hp)
				target.current_shield_hp = 0
				target.is_shield_active  = false
				target.current_hp        -= overflow
				dealt                    = overflow
				await _shatter_shield(idx)
				_show_floating_text("BREAK!", Color(1.0,0.8,0.0), _enemy_sp(idx))
				_show_floating_text(str(overflow), Color(1.0,0.95,0.3), _enemy_sp(idx)+Vector2(0,-35))
			else:
				_show_floating_text(str(actual)+" ⬡", Color(0.5,0.8,1.0), _enemy_sp(idx))
				dealt = 0
		else:
			target.current_hp -= actual
			dealt              = actual
			_show_floating_text(str(actual), Color(1.0,0.95,0.3), _enemy_sp(idx))
	else:
		target.current_hp -= actual
		dealt              = actual
		_show_floating_text(str(actual), Color(1.0,0.95,0.3), _enemy_sp(idx))

	_update_enemy_ui(idx)

	if target.current_hp <= 0:
		_give_energy_action(current_character, ENERGY_FROM_KILL)
		await _on_enemy_defeated(idx)

	return dealt

func _enemy_sp(idx: int) -> Vector2:
	if not camera: return Vector2(400,200)
	return camera.unproject_position(_get_enemy_pos(idx) + Vector3(0, 2.0, 0))

func _ally_screen_pos(char_idx: int) -> Vector2:
	if not camera: return Vector2(200, 300)
	return camera.unproject_position(_get_ally_pos(char_idx) + Vector3(0, 2.0, 0))

func _on_enemy_defeated(idx: int):
	if idx < enemy_ui_nodes.size():
		var ui = enemy_ui_nodes[idx]
		if ui and is_instance_valid(ui.root):
			var t = create_tween()
			t.tween_property(ui.root, "modulate:a", 0.0, 0.4)
			await t.finished
			ui.root.queue_free()
		enemy_ui_nodes.remove_at(idx)
	enemies.remove_at(idx)
	targeted_enemy_index = clamp(targeted_enemy_index, 0, max(0, enemies.size()-1))
	_refresh_enemy_highlight()
	check_battle_end()

# ─────────────────────────────────────────────
#  Skill effects
# ─────────────────────────────────────────────
func resolve_skill_effects():
	if current_skill == null: return
	match current_skill.effect_type:
		"Buff":
			if current_skill.is_aoe() or current_skill.target_type == "Team":
				for cd in GameManager.player_party:
					apply_buff(cd, current_skill.get_actual_effect_value(), current_skill.effect_duration)
			else:
				apply_buff(GameManager.player_party[targeted_ally_index],
					current_skill.get_actual_effect_value(), current_skill.effect_duration)
		"Debuff":
			if enemies.size() > 0:
				apply_debuff(enemies[targeted_enemy_index],
					current_skill.get_actual_effect_value(), current_skill.effect_duration)
		"Heal":
			if current_skill.is_aoe() or current_skill.target_type == "Team":
				for i in range(GameManager.player_party.size()): _apply_heal(i)
			else:
				_apply_heal(targeted_ally_index)
		"Shield":
			if current_skill.is_aoe() or current_skill.target_type == "Team":
				for i in range(GameManager.player_party.size()): _apply_shield(i)
			else:
				_apply_shield(targeted_ally_index)

func _apply_heal(char_idx: int):
	if char_idx >= GameManager.player_party.size(): return
	var cd     = GameManager.player_party[char_idx]
	var max_hp = float(cd.get_actual_hp())
	var heal   = float(current_skill.get_actual_heal_flat()) + (max_hp * current_skill.get_actual_heal_scaling())
	character_hp[char_idx] = min(character_hp[char_idx] + heal, max_hp)
	_update_portrait_hp(char_idx)
	_show_floating_text("+" + str(int(heal)) + " HP", Color(0.3,1.0,0.5), _ally_screen_pos(char_idx))

func _apply_shield(char_idx: int):
	if char_idx >= GameManager.player_party.size(): return
	var shield_val = float(current_skill.get_actual_shield_flat()) + \
		(float(current_character.get_actual_defense()) * current_skill.get_actual_shield_scaling())
	character_shields[char_idx] += shield_val
	_update_portrait_hp(char_idx)
	_show_floating_text("🛡 " + str(int(shield_val)), Color(0.4,0.7,1.0), _ally_screen_pos(char_idx))

func apply_buff(target, atk_bonus: float, duration: int):
	active_buffs[target] = {"atk_bonus": atk_bonus, "turns_left": duration}

func apply_debuff(target, def_reduction: float, duration: int):
	active_debuffs[target] = {"def_reduction": def_reduction, "turns_left": duration}

func _tick_status_effects():
	for d in [active_buffs, active_debuffs]:
		var remove = []
		for key in d:
			d[key].turns_left -= 1
			if d[key].turns_left <= 0: remove.append(key)
		for k in remove: d.erase(k)

# ─────────────────────────────────────────────
#  Turn damage display
# ─────────────────────────────────────────────
func _show_turn_damage(amount: int):
	var old = get_node_or_null("BattleUI/TurnDmgLabel")
	if old: old.queue_free()
	var lbl = Label.new()
	lbl.name = "TurnDmgLabel"
	lbl.text = str(amount) + " DMG"
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	
	# Add shadow
	lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lbl.offset_left   = -200.0
	lbl.offset_top    = 60.0
	lbl.offset_right  = -10.0
	lbl.offset_bottom = 110.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$BattleUI.add_child(lbl)
	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(lbl): return
	var t = create_tween()
	t.tween_property(lbl, "modulate:a", 0.0, 0.4)
	await t.finished
	if is_instance_valid(lbl): lbl.queue_free()

# ─────────────────────────────────────────────
#  Feedback popup
# ─────────────────────────────────────────────
func show_feedback_popup(damage: int, quality: Dictionary):
	var existing = get_node_or_null("BattleUI/FeedbackPopup")
	if existing: existing.queue_free()

	var popup = PanelContainer.new()
	popup.name = "FeedbackPopup"
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05,0.05,0.08,0.92)
	for c in ["top_left","top_right","bottom_left","bottom_right"]: s.set("corner_radius_"+c, 12)
	s.border_width_left=2; s.border_width_right=2; s.border_width_top=2; s.border_width_bottom=2
	s.border_color = Color(0.4,0.4,0.6)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	popup.add_theme_stylebox_override("panel", s)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.size = Vector2(280,0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	for cfg in [
		{"text":"⚔  Attack Result","size":16,"color":Color.WHITE},
		{"text":str(damage)+" DMG","size":28,"color":Color(1.0,0.95,0.3)}
	]:
		var lbl = Label.new()
		lbl.text = cfg.text
		lbl.add_theme_font_size_override("font_size", cfg.size)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", cfg.color)
		vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())
	for line in quality.feedback_lines:
		var lbl = Label.new()
		lbl.text = line.text
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", line.color)
		vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())

	var ml = Label.new()
	ml.text = "Sentence quality: " + str(int(quality.total_multiplier * 100)) + "%"
	ml.add_theme_font_size_override("font_size", 12)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.add_theme_color_override("font_color", Color(0.7,0.7,0.9))
	vbox.add_child(ml)
	popup.add_child(vbox)
	$BattleUI.add_child(popup)

	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(popup): return
	var t = create_tween()
	t.tween_property(popup, "modulate:a", 0.0, 0.5)
	await t.finished
	if is_instance_valid(popup): popup.queue_free()

# ─────────────────────────────────────────────
#  Floating text
# ─────────────────────────────────────────────
func _show_floating_text(text: String, color: Color, pos: Vector2):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	
	# Add shadow so numbers stand out on bright backgrounds
	lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	
	lbl.position = pos
	$BattleUI.add_child(lbl)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", pos.y - 80, 1.0)
	t.tween_property(lbl, "modulate:a", 0.0, 1.0)
	await t.finished
	if is_instance_valid(lbl): lbl.queue_free()

# ─────────────────────────────────────────────
#  Enemy turn
# ─────────────────────────────────────────────
func enemy_turn(entry: Dictionary):
	print(entry.data.enemy_name, " attacks!")
	await get_tree().create_timer(1.5).timeout
	if GameManager.player_party.size() == 0:
		current_turn_index += 1
		process_next_turn()
		return

	var target_idx = randi() % GameManager.player_party.size()
	var cd         = GameManager.player_party[target_idx]
	var raw_dmg    = entry.data.base_attack

	if character_shields[target_idx] > 0.0:
		var absorbed = min(character_shields[target_idx], float(raw_dmg))
		character_shields[target_idx] -= absorbed
		raw_dmg -= int(absorbed)
		_show_floating_text("🛡 " + str(int(absorbed)), Color(0.4,0.7,1.0), _ally_screen_pos(target_idx))

	if raw_dmg > 0:
		character_hp[target_idx] = max(0.0, character_hp[target_idx] - float(raw_dmg))
		_give_energy_hit_taken(cd)
		_show_floating_text(str(raw_dmg), Color(1.0,0.3,0.3), _ally_screen_pos(target_idx))

	_update_portrait_hp(target_idx)

	if character_hp[target_idx] <= 0:
		print(cd.character_name, " has fallen!")
		if target_idx < portrait_containers.size() and is_instance_valid(portrait_containers[target_idx]):
			var t = create_tween()
			t.tween_property(portrait_containers[target_idx], "modulate:a", 0.3, 0.4)
		GameManager.player_party.remove_at(target_idx)
		character_hp.remove_at(target_idx)
		character_shields.remove_at(target_idx)
		turn_queue = turn_queue.filter(func(t):
			if t.type == "player": return GameManager.player_party.has(t.data)
			return true
		)
		check_battle_end()
		if enemies.size() == 0 or GameManager.player_party.size() == 0:
			return

	current_turn_index += 1
	process_next_turn()

# ─────────────────────────────────────────────
#  Battle end
# ─────────────────────────────────────────────
func check_battle_end():
	if enemies.size() == 0:
		print("Victory!")
		await get_tree().create_timer(2.0).timeout
		await SupabaseManager.add_pulls(1)
		GameManager.end_combat()
		get_tree().change_scene_to_file(origin_scene)
	elif GameManager.player_party.size() == 0:
		print("Defeat!")
		await get_tree().create_timer(2.0).timeout
		GameManager.end_combat()
		get_tree().change_scene_to_file(origin_scene)

# ─────────────────────────────────────────────
#  Turn order UI
# ─────────────────────────────────────────────
func update_turn_order_ui():
	for child in turn_order_ui.get_children(): child.queue_free()
	for i in range(min(5, turn_queue.size())):
		var idx  = (current_turn_index + i) % turn_queue.size()
		var turn = turn_queue[idx]
		var lbl  = Label.new()
		lbl.text = turn.data.character_name if turn.type == "player" \
			else turn.data.data.enemy_name
		
		# Add shadow for readability against world
		lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
			
		if i == 0: lbl.add_theme_color_override("font_color", Color.YELLOW)
		turn_order_ui.add_child(lbl)

# ─────────────────────────────────────────────
#  SP display (Layout Overlap Fix Added)
# ─────────────────────────────────────────────
func _update_sp_display():
	for child in sp_stars.get_children(): child.queue_free()
	
	# Fixes the overlap by dynamically forcing the stars to render below the skill buttons
	if skill_btn:
		sp_stars.position = Vector2(skill_btn.position.x, skill_btn.position.y + 160)
	
	for i in range(max_sp):
		var star = Label.new()
		star.text = "★" if i < current_sp else "☆"
		star.add_theme_font_size_override("font_size", 24)
		star.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
		star.add_theme_constant_override("shadow_offset_x", 1)
		star.add_theme_constant_override("shadow_offset_y", 1)
		star.add_theme_color_override("font_color",
			Color(1.0,0.85,0.2) if i < current_sp else Color(0.4,0.4,0.4))
			
		# If you haven't explicitly set SPStars to an HBoxContainer in your scene,
		# this ensures they still line up perfectly horizontally instead of stacking
		if not sp_stars is BoxContainer:
			star.position = Vector2(i * 22, 0)
			
		sp_stars.add_child(star)

# ─────────────────────────────────────────────
#  Battle sprites
# ─────────────────────────────────────────────
func _setup_battle_sprites():
	for child in $Background.get_children():
		if child.name.begins_with("player_") or child.name.begins_with("enemy_") \
			or child.name.begins_with("Placeholder_"): child.queue_free()
	for i in range(GameManager.player_party.size()):
		_spawn_character(GameManager.player_party[i], i)
	for i in range(enemies.size()):
		_spawn_enemy_sprite(i)
	_build_enemy_ui()
	targeted_enemy_index = 0
	_refresh_enemy_highlight()

func _spawn_character(data: CharacterData, idx: int):
	var scene_path = "res://Characters/" + data.character_name.to_lower() + ".tscn"
	var scene = load(scene_path) if ResourceLoader.exists(scene_path) else null
	if scene == null: 
		_create_placeholder(data, idx)
		return
	var inst = scene.instantiate()
	if inst.has_method("setup"): inst.setup(data, "player")
	inst.scale    = Vector3(4.0, 4.0, 4.0)
	inst.position = _get_ally_pos(idx)
	inst.name     = "player_" + data.character_name
	$Background.add_child(inst)

func _spawn_enemy_sprite(idx: int):
	var sprite = AnimatedSprite3D.new()
	sprite.name     = "enemy_sprite_" + str(idx)
	sprite.position = _get_enemy_pos(idx)
	sprite.scale    = Vector3(5.0, 5.0, 1)
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2))
	var frames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", ImageTexture.create_from_image(img))
	sprite.sprite_frames = frames
	sprite.animation     = "idle"
	$Background.add_child(sprite)

func _create_placeholder(data: CharacterData, idx: int):
	var sprite = AnimatedSprite3D.new()
	sprite.name = "player_" + data.character_name
	if data.splash_art:
		var frames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", data.splash_art)
		sprite.sprite_frames = frames
		sprite.animation     = "idle"
		sprite.pixel_size    = 0.01
	else:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		match data.element:
			"Water": img.fill(Color(0.2,0.4,0.9))
			"Fire":  img.fill(Color(0.9,0.3,0.1))
			"Earth": img.fill(Color(0.6,0.4,0.2))
			"Wind":  img.fill(Color(0.2,0.8,0.4))
			_:       img.fill(Color(0.5,0.5,0.5))
		var frames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", ImageTexture.create_from_image(img))
		sprite.sprite_frames = frames
		sprite.animation     = "idle"
	sprite.position = _get_ally_pos(idx)
	sprite.scale    = Vector3(5.0, 5.0, 1)
	$Background.add_child(sprite)
