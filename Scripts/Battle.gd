extends Node3D

# ═══════════════════════════════════════════════════════
#  UI References
# ═══════════════════════════════════════════════════════
@onready var card_panel         := $BattleUI/CardPanel
@onready var card_grid          := $BattleUI/CardPanel/CardGrid
@onready var sentence_bar       := $BattleUI/CardPanel/SentenceBar
@onready var sentence_container := $BattleUI/CardPanel/SentenceBar/Margin/HBox/SentenceContainer
@onready var submit_btn         := $BattleUI/CardPanel/SentenceBar/Margin/HBox/SubmitButton
@onready var turn_order_ui      := $BattleUI/TurnOrder
@onready var char_portraits     := $BattleUI/BottomLeft/CharPortraits
@onready var skill_buttons      := $BattleUI/BottomRight
@onready var basic_btn          := $BattleUI/BottomRight/ActionPanel/Buttons/BasicButton
@onready var skill_btn          := $BattleUI/BottomRight/ActionPanel/Buttons/SkillButton
@onready var sp_stars           := $BattleUI/BottomRight/ActionPanel/SPStars
@onready var camera             := $Camera3D

# ═══════════════════════════════════════════════════════
#  Card system
# ═══════════════════════════════════════════════════════
const CARD_SCENE := preload("res://Scenes/Card.tscn")
var hand:              Array = []  # WordCard resources
var current_hand_nodes: Array = []
var sentence:          Array = []  # WordCard resources in current sentence

# ═══════════════════════════════════════════════════════
#  Dynamic UI storage
# ═══════════════════════════════════════════════════════
var ult_buttons:         Array = []
var portrait_containers: Array = []
var portrait_hp_bars:    Array = []
var portrait_hp_labels:  Array = []
var portrait_shields:    Array = []
var enemy_ui_nodes:      Array = []

# ═══════════════════════════════════════════════════════
#  Battle state
# ═══════════════════════════════════════════════════════
var turn_queue:          Array         = []
var current_turn_index:  int           = 0
var current_character:   CharacterData = null
var current_skill:       SkillData     = null
var current_sp:          int           = 3
var max_sp:              int           = 5
var enemies:             Array         = []
var is_player_turn:      bool          = true

var character_hp:      Array = []
var character_shields: Array = []

var targeted_enemy_index: int  = 0
var targeted_ally_index:  int  = 0
var is_targeting_ally:    bool = false
var selected_skill_slot:  String = "basic"

var active_buffs:   Dictionary = {}
var active_debuffs: Dictionary = {}
var origin_scene:   String = "res://Scenes/forest.tscn"

# ── Turn locks ───────────────────────────────────────
var _is_processing_turn: bool = false
var _is_selecting_skill: bool = false

# ═══════════════════════════════════════════════════════
#  Camera
# ═══════════════════════════════════════════════════════
const CAM_DEFAULT_POS    := Vector3(-5.0, 3.5,  9.0)
const CAM_DEFAULT_TARGET := Vector3( 1.0, 1.0, -1.0)
const CAM_ALLY_POS       := Vector3(-7.0, 3.0,  6.0)
const CAM_ALLY_TARGET    := Vector3(-2.0, 1.5,  1.0)

# ═══════════════════════════════════════════════════════
#  Constants
# ═══════════════════════════════════════════════════════
const CARD_COLORS := {
	"Action"   : Color(0.85, 0.35, 0.28),
	"Noun"     : Color(0.20, 0.50, 0.85),
	"Number"   : Color(0.20, 0.75, 0.40),
	"Adjective": Color(0.75, 0.50, 0.85),
	"Pronoun"  : Color(0.90, 0.60, 0.10),
}

const PENALTY_NO_AFFIX      := 0.10
const PENALTY_WRONG_GRAMMAR := 0.20
const DEF_SCALAR            := 0.30
const SPEED_JITTER          := 0.15
const ENCOUNTER_WEIGHTS     := [15, 40, 35, 10]

const ENERGY_FROM_BASIC     := 20.0
const ENERGY_FROM_SKILL     := 30.0
const ENERGY_FROM_KILL      := 10.0
const ENERGY_FROM_HIT_TAKEN := 10.0

# ═══════════════════════════════════════════════════════
#  3D Placement
# ═══════════════════════════════════════════════════════
const FLOOR_OFFSET := 1.8

func _get_ally_pos(idx: int) -> Vector3:
	return Vector3(-3.0 - idx * 1.5, FLOOR_OFFSET, 4.5 - idx * 1.0)

func _get_enemy_pos(idx: int) -> Vector3:
	return Vector3(2.5 + idx * 3.0, FLOOR_OFFSET, -2.2 + idx * 1.0)

# ═══════════════════════════════════════════════════════
#  _ready
# ═══════════════════════════════════════════════════════
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	card_panel.visible    = false
	skill_buttons.visible = false

	await _stabilize_terrain()

	var transition = get_tree().get_first_node_in_group("transition")
	if transition:
		transition.fade_in()

	if GameManager.has_meta("last_scene"):
		origin_scene = GameManager.get_meta("last_scene")

	_init_character_hp()

	basic_btn.pressed.connect(_on_basic_btn_pressed)
	skill_btn.pressed.connect(_on_skill_btn_pressed)
	submit_btn.pressed.connect(_on_submit_pressed)

	# Apply Premium Styles
	_setup_card_panel_bg()
	_style_circular_button(basic_btn, Color(0.72, 0.58, 0.42))
	_style_circular_button(skill_btn, Color(0.85, 0.35, 0.28))
	
	_spawn_enemies_for_zone()
	_build_turn_queue()
	_setup_character_portraits()
	_setup_battle_sprites()
	draw_hand()
	start_battle()

	if camera:
		camera.position = CAM_DEFAULT_POS
		camera.look_at(CAM_DEFAULT_TARGET, Vector3.UP)


func _stabilize_terrain() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw

	var terrain = find_child("MarchingSquaresTerrain", true, false)
	if not terrain:
		return

	terrain.set_process(false)
	terrain.set_physics_process(false)
	terrain.visible = false

	for method in ["clear_cache", "reset", "free_chunks"]:
		if terrain.has_method(method):
			terrain.call(method)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	terrain.visible = true
	terrain.set_process(true)
	terrain.set_physics_process(true)

	await get_tree().create_timer(0.1).timeout

	for method in ["force_update", "update_terrain", "generate"]:
		if terrain.has_method(method):
			terrain.call(method)
			break

	await RenderingServer.frame_post_draw


func _init_character_hp() -> void:
	character_hp.clear()
	character_shields.clear()
	for character in GameManager.player_party:
		character_hp.append(float(character.get_actual_hp()))
		character_shields.append(0.0)

# ═══════════════════════════════════════════════════════
#  Card System
# ═══════════════════════════════════════════════════════
func draw_hand() -> void:
	for node in current_hand_nodes:
		if is_instance_valid(node):
			node.queue_free()
	current_hand_nodes.clear()
	hand.clear()

	var all_cards := _load_all_cards()
	_ensure_required_card_types(all_cards)
	all_cards.shuffle()

	for i in range(min(7, all_cards.size())):
		var card_data: WordCard = all_cards[i]
		hand.append(card_data)
		var card_node = CARD_SCENE.instantiate()
		card_node.card_data = card_data
		card_grid.add_child(card_node)
		current_hand_nodes.append(card_node)
		card_node.card_selected.connect(_on_card_toggled)

	update_sentence_display()


func _load_all_cards() -> Array:
	var result := []
	var dir := DirAccess.open("res://Resources/Cards/")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".tres"):
				var card = load("res://Resources/Cards/" + f)
				if card is WordCard:
					result.append(card)
	return result


func _ensure_required_card_types(cards: Array) -> void:
	var has := {"Action": false, "Noun": false, "Pronoun": false}
	for card in cards:
		if has.has(card.card_type):
			has[card.card_type] = true

	var defaults := {
		"Action":  {"kapampangan_text": "Gawa",  "english_hint": "Do/Action",  "card_type": "Action"},
		"Noun":    {"kapampangan_text": "Bagay", "english_hint": "Thing/Noun", "card_type": "Noun"},
		"Pronoun": {"kapampangan_text": "Aku",   "english_hint": "I/Me",       "card_type": "Pronoun"},
	}
	for type in has:
		if not has[type]:
			var c := WordCard.new()
			for key in defaults[type]:
				c.set(key, defaults[type][key])
			cards.append(c)


func _on_card_toggled(card_data: WordCard) -> void:
	if _is_processing_turn or _is_selecting_skill:
		return
	if sentence.has(card_data):
		sentence.erase(card_data)
	else:
		sentence.append(card_data)
	for node in current_hand_nodes:
		if node.card_data == card_data:
			node.set_highlight(sentence.has(card_data))
	update_sentence_display()


func update_sentence_display() -> void:
	for child in sentence_container.get_children():
		child.queue_free()

	if sentence.is_empty():
		var ph := Label.new()
		ph.text = "Select cards to build your sentence..."
		ph.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		sentence_container.add_child(ph)
		return

	for card in sentence:
		var pill := PanelContainer.new()
		var s := _make_rounded_stylebox(CARD_COLORS.get(card.card_type, Color(0.5, 0.5, 0.5)), 20)
		s.border_width_bottom = 2
		s.border_color        = s.bg_color.darkened(0.3)
		pill.add_theme_stylebox_override("panel", s)

		var lbl := Label.new()
		lbl.text = card.kapampangan_text
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 16)
		pill.add_child(lbl)

		var btn := Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(func():
			sentence.erase(card)
			update_sentence_display()
			for node in current_hand_nodes:
				if node.card_data == card:
					node.set_highlight(false)
		)
		pill.add_child(btn)
		sentence_container.add_child(pill)

# ═══════════════════════════════════════════════════════
#  Input
# ═══════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	# Global Input: Pause Menu via Escape
	if event.is_action_pressed("ui_cancel"):
		var pause_menu = load("res://Scenes/PauseMenu.tscn").instantiate()
		get_tree().root.add_child(pause_menu)
		return

	# Combat Inputs
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not is_player_turn:
		return

	if is_targeting_ally:
		match event.keycode:
			KEY_A:            _navigate_ally(-1)
			KEY_D:            _navigate_ally(1)
			KEY_ENTER, KEY_SPACE: _confirm_ally_target()
		return

	if card_panel.visible:
		return

	match event.keycode:
		KEY_Q:
			if selected_skill_slot == "basic": _activate_selected_skill()
			else: selected_skill_slot = "basic"; _refresh_skill_highlights()
		KEY_E:
			if selected_skill_slot == "skill": _activate_selected_skill()
			else: selected_skill_slot = "skill"; _refresh_skill_highlights()
		KEY_1: _trigger_ult(0)
		KEY_2: _trigger_ult(1)
		KEY_3: _trigger_ult(2)
		KEY_4: _trigger_ult(3)
		KEY_A: _navigate_enemy(-1)
		KEY_D: _navigate_enemy(1)

# ═══════════════════════════════════════════════════════
#  Enemy targeting & UI Toggles
# ═══════════════════════════════════════════════════════
func _set_enemy_ui_visible(is_visible: bool) -> void:
	for ui in enemy_ui_nodes:
		if ui and is_instance_valid(ui.root):
			ui.root.visible = is_visible

func _navigate_enemy(dir: int) -> void:
	_set_enemy_target(targeted_enemy_index + dir)

func _set_enemy_target(idx: int) -> void:
	targeted_enemy_index = clamp(idx, 0, enemies.size() - 1)
	_refresh_enemy_highlight()

func _refresh_enemy_highlight() -> void:
	for i in range(enemy_ui_nodes.size()):
		var ui = enemy_ui_nodes[i]
		if not ui or not is_instance_valid(ui.root):
			continue
		ui.root.modulate = Color(1.5, 1.2, 0.4) if i == targeted_enemy_index else Color.WHITE

# ═══════════════════════════════════════════════════════
#  Ally targeting
# ═══════════════════════════════════════════════════════
func _begin_ally_targeting() -> void:
	_is_selecting_skill = false
	is_targeting_ally   = true
	targeted_ally_index = _index_of_current_char()
	_refresh_ally_highlight()
	_pan_camera(CAM_ALLY_POS, CAM_ALLY_TARGET, CAM_DEFAULT_TARGET)

func _navigate_ally(dir: int) -> void:
	targeted_ally_index = clamp(targeted_ally_index + dir, 0, GameManager.player_party.size() - 1)
	_refresh_ally_highlight()

func _confirm_ally_target() -> void:
	is_targeting_ally = false
	_refresh_ally_highlight()
	_pan_camera_to_default()
	show_card_panel()

func _refresh_ally_highlight() -> void:
	for i in range(portrait_containers.size()):
		var is_targeted = (i == targeted_ally_index)
		portrait_containers[i].modulate = Color(1.5, 1.3, 0.5) if is_targeted else Color.WHITE

func _index_of_current_char() -> int:
	return GameManager.player_party.find(current_character)

func _pan_camera(to_pos: Vector3, to_target: Vector3, from_target: Vector3) -> void:
	if not camera: return
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(camera, "position", to_pos, 0.4).set_trans(Tween.TRANS_QUAD)
	t.tween_method(func(v): camera.look_at(v, Vector3.UP), from_target, to_target, 0.4).set_trans(Tween.TRANS_QUAD)

func _pan_camera_to_default() -> void:
	_pan_camera(CAM_DEFAULT_POS, CAM_DEFAULT_TARGET, CAM_ALLY_TARGET)

# ═══════════════════════════════════════════════════════
#  Skill selection
# ═══════════════════════════════════════════════════════
func _activate_selected_skill() -> void:
	match selected_skill_slot:
		"basic": _on_basic_pressed()
		"skill": _on_skill_pressed()

func _refresh_skill_highlights() -> void:
	_restyle_slot_btn(basic_btn, Color(0.72, 0.58, 0.42), selected_skill_slot == "basic")
	_restyle_slot_btn(skill_btn, Color(0.85, 0.35, 0.28), selected_skill_slot == "skill")

func _restyle_slot_btn(btn: Button, color: Color, active: bool) -> void:
	var target_size = Vector2(160, 160) if active else Vector2(110, 110)
	
	# Smooth size transition
	var t = create_tween()
	t.tween_property(btn, "custom_minimum_size", target_size, 0.15).set_trans(Tween.TRANS_SINE)

	var s := _make_rounded_stylebox(color if active else color.darkened(0.45), 999)
	var bw := 4 if active else 1
	s.border_width_left   = bw; s.border_width_right = bw
	s.border_width_top    = bw; s.border_width_bottom = bw
	s.border_color        = color.lightened(0.5) if active else color.darkened(0.2)
	s.shadow_color        = color if active else Color(0, 0, 0, 0.5)
	s.shadow_size         = 15 if active else 3
	s.shadow_offset       = Vector2(0, 4) if active else Vector2(0, 2)
	btn.add_theme_stylebox_override("normal", s)

	var h := _make_rounded_stylebox(color.lightened(0.2), 999)
	h.border_width_left   = 4; h.border_width_right  = 4
	h.border_width_top    = 4; h.border_width_bottom = 4
	h.border_color        = color.lightened(0.8)
	h.shadow_color        = color.lightened(0.4)
	h.shadow_size         = 20
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_font_size_override("font_size", 18 if active else 14)

func _trigger_ult(idx: int) -> void:
	if _is_selecting_skill or _is_processing_turn: return
	if idx >= GameManager.player_party.size():       return
	var cd: CharacterData = GameManager.player_party[idx]
	if cd.ultimate == null or not cd.is_ult_ready():
		print("Ult not ready for ", cd.character_name)
		return
	_is_selecting_skill = true
	current_character   = cd
	current_skill       = cd.ultimate as SkillData
	_decide_targeting()

# ═══════════════════════════════════════════════════════
#  Targeting decision
# ═══════════════════════════════════════════════════════
func _decide_targeting() -> void:
	if current_skill == null: return
	if current_skill.targets_ally() and current_skill.target_type == "Single":
		_begin_ally_targeting()
	else:
		show_card_panel()

# ═══════════════════════════════════════════════════════
#  Enemy spawning
# ═══════════════════════════════════════════════════════
func _spawn_enemies_for_zone() -> void:
	enemies.clear()
	var pool := _get_enemy_pool()
	if pool.is_empty():
		if GameManager.active_enemy_data:
			pool = [GameManager.active_enemy_data]
		else:
			push_error("No enemy pool!")
			return

	pool.shuffle()
	var count := _weighted_count()
	for i in range(count):
		var data: EnemyData = pool[i % pool.size()]
		var spd := int(data.speed * (1.0 + randf_range(-SPEED_JITTER, SPEED_JITTER)))
		enemies.append({
			"data":              data,
			"current_hp":        data.get_actual_hp(),
			"current_shield_hp": data.get_actual_shield_hp(),
			"is_shield_active":  data.is_shield_active,
			"speed":             spd,
			"index":             i,
		})
	print("Spawned %d enemies" % enemies.size())


func _get_enemy_pool() -> Array:
	var pools := {
		"res://Scenes/Zone1.tscn": [
			load("res://Resources/Enemies/kalapati.tres"),
			load("res://Resources/Enemies/dagis.tres"),
		],
		"res://Scenes/HubTown.tscn": [
			load("res://Resources/Enemies/dagis.tres"),
		],
	}
	if pools.has(origin_scene):
		return pools[origin_scene]

	var fallback := []
	var dir := DirAccess.open("res://Resources/Enemies/")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".tres"):
				fallback.append(load("res://Resources/Enemies/" + f))
	return fallback


func _weighted_count() -> int:
	var total := 0
	for w in ENCOUNTER_WEIGHTS: total += w
	var roll  := randi() % total
	var cum   := 0
	for i in range(ENCOUNTER_WEIGHTS.size()):
		cum += ENCOUNTER_WEIGHTS[i]
		if roll < cum: return i + 1
	return 2

# ═══════════════════════════════════════════════════════
#  Turn queue
# ═══════════════════════════════════════════════════════
func _build_turn_queue() -> void:
	turn_queue.clear()
	for character in GameManager.player_party:
		var spd := int(character.speed * (1.0 + randf_range(-SPEED_JITTER, SPEED_JITTER)))
		turn_queue.append({"type": "player", "data": character, "speed": spd})
	for enemy in enemies:
		turn_queue.append({"type": "enemy", "data": enemy, "speed": enemy.speed})
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)

# ═══════════════════════════════════════════════════════
#  Enemy HP / Shield UI
# ═══════════════════════════════════════════════════════
func _build_enemy_ui() -> void:
	for ui in enemy_ui_nodes:
		if ui and is_instance_valid(ui.root):
			ui.root.queue_free()
	enemy_ui_nodes.clear()

	for i in range(enemies.size()):
		var enemy  = enemies[i]
		var w_pos  := _get_enemy_pos(i)
		var root   := Control.new()
		root.name                  = "EnemyUI_" + str(i)
		root.custom_minimum_size   = Vector2(160, 64)
		root.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		$BattleUI.add_child(root)

		# Shield bar
		var shield_bar := ProgressBar.new()
		shield_bar.custom_minimum_size = Vector2(150, 7)
		shield_bar.max_value           = float(max(1, enemy.data.get_actual_shield_hp()))
		shield_bar.value               = float(enemy.current_shield_hp)
		shield_bar.show_percentage     = false
		shield_bar.visible             = enemy.is_shield_active
		shield_bar.position            = Vector2(5, 0)
		_style_bar(shield_bar, Color(0.4, 0.7, 1.0), Color(0.1, 0.2, 0.4))
		root.add_child(shield_bar)

		# HP bar
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(150, 11)
		hp_bar.max_value           = float(enemy.data.get_actual_hp())
		hp_bar.value               = float(enemy.current_hp)
		hp_bar.show_percentage     = false
		hp_bar.position            = Vector2(5, 9)
		_style_bar(hp_bar, Color(0.2, 0.85, 0.35), Color(0.1, 0.25, 0.1))
		root.add_child(hp_bar)

		# HP label
		var hp_lbl := _make_label(
			_hp_text(enemy.current_hp, enemy.data.get_actual_hp()), 10,
			Color.WHITE, Vector2(5, 22), Vector2(150, 14)
		)
		root.add_child(hp_lbl)

		# Name label
		var name_lbl := _make_label(
			enemy.data.enemy_name, 11,
			Color(1.0, 0.85, 0.5), Vector2(5, 38), Vector2(150, 14)
		)
		root.add_child(name_lbl)

		# Click-to-target button
		var btn := Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(_set_enemy_target.bind(i))
		root.add_child(btn)

		enemy_ui_nodes.append({
			"root":       root,
			"hp_bar":     hp_bar,
			"shield_bar": shield_bar,
			"hp_label":   hp_lbl,
			"world_pos":  w_pos,
		})


func _make_label(text: String, font_size: int, color: Color,
		pos: Vector2, sz: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text                     = text
	lbl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position                 = pos
	lbl.size                     = sz
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


func _style_bar(bar: ProgressBar, fill: Color, bg: Color) -> void:
	var sf := _make_rounded_stylebox(fill, 4)
	var sb := _make_rounded_stylebox(bg,   4)
	sb.border_width_left   = 1; sb.border_width_right  = 1
	sb.border_width_top    = 1; sb.border_width_bottom = 1
	sb.border_color        = Color(0.05, 0.05, 0.05, 0.8)
	bar.add_theme_stylebox_override("fill",       sf)
	bar.add_theme_stylebox_override("background", sb)


func _hp_text(current: float, maximum: int) -> String:
	return "%d/%d" % [max(0, int(current)), maximum]


func _process(_delta: float) -> void:
	if not camera: return
	for ui in enemy_ui_nodes:
		# OPTIMIZATION: Do not calculate screen positions if the UI is hidden or invalid!
		if not ui or not is_instance_valid(ui.root) or not ui.root.visible: continue
		var sp: Vector2 = camera.unproject_position(ui.world_pos + Vector3(0, 2.8, 0))
		ui.root.position = sp - Vector2(75, 0)


func _update_enemy_ui(idx: int) -> void:
	if idx >= enemy_ui_nodes.size() or idx >= enemies.size(): return
	var ui    = enemy_ui_nodes[idx]
	var enemy = enemies[idx]
	if not ui or not is_instance_valid(ui.root): return
	
	# Smoothly animate HP reduction
	create_tween().tween_property(ui.hp_bar, "value", float(max(0, enemy.current_hp)), 0.3).set_trans(Tween.TRANS_SINE)
	
	ui.hp_label.text       = _hp_text(enemy.current_hp, enemy.data.get_actual_hp())
	ui.shield_bar.visible  = enemy.is_shield_active
	if enemy.is_shield_active:
		create_tween().tween_property(ui.shield_bar, "value", float(enemy.current_shield_hp), 0.3).set_trans(Tween.TRANS_SINE)


func _shatter_shield(idx: int) -> void:
	if idx >= enemy_ui_nodes.size(): return
	var ui = enemy_ui_nodes[idx]
	if not ui or not is_instance_valid(ui.root): return
	var sb := ui.shield_bar as ProgressBar
	var t  := create_tween()
	t.tween_property(sb, "modulate", Color(2, 2, 2),    0.05)
	t.tween_property(sb, "modulate", Color(1, 1, 1),    0.05)
	t.tween_property(sb, "modulate", Color(2, 2, 2),    0.05)
	t.tween_property(sb, "modulate", Color(0, 0, 0, 0), 0.15)
	await t.finished
	sb.visible  = false
	sb.modulate = Color.WHITE
	# Flash enemy sprite on break
	var sprite = $Background.get_node_or_null("enemy_sprite_" + str(idx))
	if sprite:
		var st := create_tween()
		st.tween_property(sprite, "modulate", Color(3, 3, 1), 0.05)
		st.tween_property(sprite, "modulate", Color.WHITE,    0.25)

# ═══════════════════════════════════════════════════════
#  Portrait HP / Shield
# ═══════════════════════════════════════════════════════
func _update_portrait_hp(char_idx: int) -> void:
	if char_idx >= GameManager.player_party.size(): return
	var cd:     CharacterData = GameManager.player_party[char_idx]
	var max_hp: float = float(cd.get_actual_hp())
	var cur_hp: float = character_hp[char_idx]
	var shield: float = character_shields[char_idx]

	if char_idx < portrait_hp_bars.size() and is_instance_valid(portrait_hp_bars[char_idx]):
		# Smooth HP animation
		create_tween().tween_property(portrait_hp_bars[char_idx], "value", max(0.0, cur_hp), 0.3).set_trans(Tween.TRANS_SINE)

	if char_idx < portrait_hp_labels.size() and is_instance_valid(portrait_hp_labels[char_idx]):
		portrait_hp_labels[char_idx].text = _hp_text(cur_hp, int(max_hp))

	if char_idx < portrait_shields.size() and is_instance_valid(portrait_shields[char_idx]):
		var shield_rect: ColorRect = portrait_shields[char_idx]
		shield_rect.visible = shield > 0.0
		if shield > 0.0:
			create_tween().tween_property(shield_rect, "size:x", 90.0 * clamp(shield / max_hp, 0.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)


func _update_energy_display(char_idx: int) -> void:
	if char_idx >= GameManager.player_party.size() or char_idx >= ult_buttons.size(): return
	var cd:  CharacterData = GameManager.player_party[char_idx]
	var btn: Button = ult_buttons[char_idx]
	var pct: float = cd.current_energy / cd.max_energy
	btn.text     = "[%d] ULT\n%d%%" % [char_idx + 1, int(pct * 100)]
	btn.disabled = not cd.is_ult_ready()
	btn.modulate = Color.WHITE if cd.is_ult_ready() else Color(0.5, 0.5, 0.5)

# ═══════════════════════════════════════════════════════
#  Energy
# ═══════════════════════════════════════════════════════
func _give_energy_action(char_data: CharacterData, base_amount: float) -> void:
	char_data.gain_energy(base_amount, true)
	var idx := GameManager.player_party.find(char_data)
	if idx >= 0:
		_update_energy_display(idx)

func _give_energy_hit_taken(char_data: CharacterData) -> void:
	char_data.gain_energy(ENERGY_FROM_HIT_TAKEN, false)
	var idx := GameManager.player_party.find(char_data)
	if idx >= 0:
		_update_energy_display(idx)

# ═══════════════════════════════════════════════════════
#  Setup helpers
# ═══════════════════════════════════════════════════════
func _make_rounded_stylebox(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	return s

func _setup_card_panel_bg() -> void:
	# Add glass panel styling to the sentence bar
	var glass = StyleBoxFlat.new()
	glass.bg_color = Color(0.12, 0.14, 0.2, 0.85)
	glass.border_width_left = 2
	glass.border_width_top = 2
	glass.border_width_right = 2
	glass.border_width_bottom = 2
	glass.border_color = Color(0.4, 0.5, 0.7, 0.6)
	glass.set_corner_radius_all(24)
	glass.shadow_color = Color(0, 0, 0, 0.3)
	glass.shadow_size = 15
	if sentence_bar:
		sentence_bar.add_theme_stylebox_override("panel", glass)

	# Style the Submit Button (Gold HSR style)
	var submit_style = StyleBoxFlat.new()
	submit_style.bg_color = Color(0.85, 0.7, 0.3)
	submit_style.set_corner_radius_all(16)
	submit_style.shadow_color = Color(0.85, 0.7, 0.3, 0.4)
	submit_style.shadow_size = 8
	if submit_btn:
		submit_btn.add_theme_stylebox_override("normal", submit_style)
		
		var submit_hover = submit_style.duplicate()
		submit_hover.bg_color = Color(0.95, 0.8, 0.4)
		submit_btn.add_theme_stylebox_override("hover", submit_hover)


func _setup_character_portraits() -> void:
	for child in char_portraits.get_children(): child.queue_free()
	ult_buttons.clear()
	portrait_containers.clear()
	portrait_hp_bars.clear()
	portrait_hp_labels.clear()
	portrait_shields.clear()

	for i in range(GameManager.player_party.size()):
		var cd: CharacterData = GameManager.player_party[i]

		var panel := PanelContainer.new()
		var ps    := _make_rounded_stylebox(Color(0.12, 0.13, 0.18, 0.85), 12)
		ps.border_width_left = 1; ps.border_width_right = 1
		ps.border_width_top = 1; ps.border_width_bottom = 1
		ps.border_color = Color(0.3, 0.35, 0.5, 0.5)
		ps.content_margin_left   = 6; ps.content_margin_right  = 6
		ps.content_margin_top    = 8; ps.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", ps)

		var box := VBoxContainer.new()
		box.name                 = "Portrait%d" % (i + 1)
		box.custom_minimum_size  = Vector2(100, 185)

		# Portrait image
		var img := TextureRect.new()
		img.custom_minimum_size   = Vector2(80, 80)
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if cd.splash_art:
			img.texture      = cd.splash_art
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		box.add_child(img)

		# Name
		var name_lbl := Label.new()
		name_lbl.text                 = cd.character_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		box.add_child(name_lbl)

		# HP bar container
		var bar_container := Control.new()
		bar_container.custom_minimum_size   = Vector2(90, 14)
		bar_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var hp_bar := ProgressBar.new()
		hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_bar.max_value       = float(cd.get_actual_hp())
		hp_bar.value           = float(cd.get_actual_hp())
		hp_bar.show_percentage = false
		_style_bar(hp_bar, Color(0.2, 0.85, 0.35), Color(0.1, 0.25, 0.1))
		bar_container.add_child(hp_bar)

		var shield_rect := ColorRect.new()
		shield_rect.color        = Color(0.4, 0.7, 1.0, 0.6)
		shield_rect.visible      = false
		shield_rect.position     = Vector2.ZERO
		shield_rect.size         = Vector2(0, 14)
		shield_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_container.add_child(shield_rect)

		box.add_child(bar_container)
		portrait_hp_bars.append(hp_bar)
		portrait_shields.append(shield_rect)

		# HP label
		var hp_lbl := Label.new()
		hp_lbl.text                 = _hp_text(float(cd.get_actual_hp()), cd.get_actual_hp())
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_font_size_override("font_size", 9)
		hp_lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		box.add_child(hp_lbl)
		portrait_hp_labels.append(hp_lbl)

		# Ult button
		var ult := Button.new()
		ult.text                 = "[%d] ULT\n%d%%" % [i + 1, int((cd.current_energy / cd.max_energy) * 100)]
		ult.custom_minimum_size  = Vector2(90, 32)
		ult.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ult.disabled             = not cd.is_ult_ready()
		ult.modulate             = Color.WHITE if cd.is_ult_ready() else Color(0.5, 0.5, 0.5)
		_style_ult_button(ult)
		ult.pressed.connect(_trigger_ult.bind(i))
		box.add_child(ult)
		ult_buttons.append(ult)

		panel.add_child(box)
		portrait_containers.append(panel)
		char_portraits.add_child(panel)


func _style_ult_button(btn: Button) -> void:
	var colors := {
		"normal":   Color(0.65, 0.20, 0.80),
		"hover":    Color(0.85, 0.40, 1.00),
		"disabled": Color(0.25, 0.10, 0.30),
	}
	for state in colors:
		var s := _make_rounded_stylebox(colors[state], 14)
		s.border_width_left   = 2; s.border_width_right  = 2
		s.border_width_top    = 2; s.border_width_bottom = 2
		s.border_color        = Color(0.9, 0.6, 1.0) if state != "disabled" else Color(0.4, 0.2, 0.5)
		s.shadow_color        = Color(0, 0, 0, 0.4)
		s.shadow_size         = 2
		s.shadow_offset       = Vector2(0, 1)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 11)


func _style_circular_button(btn: Button, color: Color) -> void:
	btn.custom_minimum_size = Vector2(110, 110)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = color
	sb.set_corner_radius_all(100)
	sb.shadow_color = color.darkened(0.5)
	sb.shadow_size = 12
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = color.darkened(0.6)
	sb_hover.border_color = color.lightened(0.3)
	sb_hover.shadow_size = 20
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)

# ═══════════════════════════════════════════════════════
#  Turn flow
# ═══════════════════════════════════════════════════════
func start_battle() -> void:
	current_turn_index   = 0
	selected_skill_slot  = "basic"
	targeted_enemy_index = 0
	_is_processing_turn  = false
	_is_selecting_skill  = false
	process_next_turn()


func process_next_turn() -> void:
	if turn_queue.is_empty(): return

	# Prune defeated combatants
	turn_queue = turn_queue.filter(func(t):
		return t.type != "enemy" or enemies.has(t.data)
	)
	if turn_queue.is_empty(): return
	if current_turn_index >= turn_queue.size():
		current_turn_index = 0

	_tick_status_effects()
	update_turn_order_ui()

	var current: Dictionary = turn_queue[current_turn_index]
	if current.type == "player":
		current_character   = current.data
		is_player_turn      = true
		selected_skill_slot = "basic"
		show_skill_buttons()
	else:
		is_player_turn = false
		await enemy_turn(current.data)


func show_skill_buttons() -> void:
	_is_selecting_skill   = false
	_is_processing_turn   = false
	submit_btn.disabled   = false
	skill_buttons.visible = true
	card_panel.visible    = false
	is_targeting_ally     = false
	_set_enemy_ui_visible(true) # <-- Toggles the enemy bars back ON

	var bd := current_character.basic_attack as SkillData
	var sd := current_character.skill as SkillData
	if bd == null or sd == null:
		push_error("Missing skills on: " + current_character.character_name)
		return

	basic_btn.text     = "[Q] Basic\n(+%d SP)" % bd.sp_gain
	skill_btn.text     = "[E] Skill\n(-%d SP)" % sd.sp_cost
	skill_btn.disabled = current_sp < sd.sp_cost

	for i in range(ult_buttons.size()):
		_update_energy_display(i)

	for i in range(portrait_containers.size()):
		portrait_containers[i].modulate = \
			Color(1.3, 1.3, 1.3) if GameManager.player_party[i] == current_character \
			else Color.WHITE

	_refresh_skill_highlights()
	_update_sp_display()
	_refresh_enemy_highlight()

# ═══════════════════════════════════════════════════════
#  Button callbacks
# ═══════════════════════════════════════════════════════
func _on_basic_btn_pressed() -> void:
	if _is_selecting_skill or _is_processing_turn: return
	if selected_skill_slot == "basic": _on_basic_pressed()
	else: selected_skill_slot = "basic"; _refresh_skill_highlights()

func _on_skill_btn_pressed() -> void:
	if _is_selecting_skill or _is_processing_turn: return
	if selected_skill_slot == "skill": _on_skill_pressed()
	else: selected_skill_slot = "skill"; _refresh_skill_highlights()

func _on_basic_pressed() -> void:
	if _is_selecting_skill or _is_processing_turn or current_character.basic_attack == null: return
	_is_selecting_skill = true
	current_skill       = current_character.basic_attack as SkillData
	_decide_targeting()

func _on_skill_pressed() -> void:
	if _is_selecting_skill or _is_processing_turn: return
	var sd := current_character.skill as SkillData
	if sd == null or current_sp < sd.sp_cost:
		print("Not enough SP!")
		return
	_is_selecting_skill = true
	current_skill       = sd
	_decide_targeting()

func show_card_panel() -> void:
	_is_selecting_skill   = false
	skill_buttons.visible = false
	card_panel.visible    = true
	sentence_bar.visible  = true
	_set_enemy_ui_visible(false) # <-- Toggles the enemy bars OFF


# ═══════════════════════════════════════════════════════
#  Submit / resolve turn
# ═══════════════════════════════════════════════════════
func _on_submit_pressed() -> void:
	if _is_processing_turn: return
	if sentence.is_empty() or (enemies.is_empty() and not current_skill.targets_ally()): return

	_is_processing_turn = true
	submit_btn.disabled = true

	var quality    := analyse_sentence_quality()
	var raw_damage := calculate_damage(quality)
	var turn_damage := 0

	if current_skill.is_damage_skill():
		if current_skill.is_aoe():
			for i in range(enemies.size()):
				turn_damage += await deal_damage(raw_damage, i)
		else:
			turn_damage = await deal_damage(raw_damage, targeted_enemy_index)

	resolve_skill_effects()

	match current_skill.skill_type.to_lower():
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

	# Consume used cards and redraw
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

# ═══════════════════════════════════════════════════════
#  Sentence quality analysis
# ═══════════════════════════════════════════════════════
func analyse_sentence_quality() -> Dictionary:
	var r := {
		"grammar_ok":       false,
		"focus_type":       "",
		"word_order_ok":    false,
		"has_affix":        false,
		"grammar_penalty":  0.0,
		"affix_penalty":    0.0,
		"total_multiplier": 1.0,
		"feedback_lines":   [],
		"example_sentence": "",
	}

	var by_type := {"Action": [], "Noun": [], "Pronoun": [], "Adjective": [], "Number": []}
	for card in sentence:
		if by_type.has(card.card_type):
			by_type[card.card_type].append(card)

	var has_action:  bool = by_type["Action"].size()  > 0
	var has_noun:    bool = by_type["Noun"].size()    > 0
	var has_pronoun: bool = by_type["Pronoun"].size() > 0

	r.word_order_ok = sentence.size() > 0 and sentence[0].card_type == "Action"

	var stype      := (current_skill.skill_type.to_lower() if current_skill.skill_type else "")
	var min_cards  := 2
	if   stype == "skill":    min_cards = 3
	elif stype == "ultimate": min_cards = 4

	var verb_text:    String = by_type["Action"][0].kapampangan_text  if has_action  else "Verb"
	var noun_text:    String = by_type["Noun"][0].kapampangan_text    if has_noun    else "Noun"
	var pronoun_text: String = by_type["Pronoun"][0].kapampangan_text if has_pronoun else "Aku"

	# Build example sentence
	match stype:
		"basic":
			r.example_sentence = "%s %s" % [verb_text, noun_text]
		"skill":
			r.example_sentence = "%s %s %s\n(Actor) or: %s %s %s (Object)" % \
				[verb_text, pronoun_text, noun_text, verb_text, noun_text, pronoun_text]
		"ultimate":
			r.example_sentence = "%s %s %s [+1 more card]" % [verb_text, pronoun_text, noun_text]

	# Detect focus types
	var is_actor_focus  := false
	var is_object_focus := false
	if r.word_order_ok and sentence.size() >= 2:
		if sentence.size() >= 3:
			is_actor_focus  = sentence[0].card_type == "Action" and sentence[1].card_type == "Pronoun" and has_noun
			is_object_focus = sentence[0].card_type == "Action" and sentence[1].card_type == "Noun"    and has_pronoun
		else:
			is_actor_focus  = sentence[0].card_type == "Action" and has_noun
			is_object_focus = is_actor_focus

	r.grammar_ok = (is_actor_focus or is_object_focus) and sentence.size() >= min_cards
	if   is_actor_focus:  r.focus_type = "Actor"
	elif is_object_focus: r.focus_type = "Object"

	# Grammar feedback
	const RED    := Color(1.0, 0.35, 0.35)
	const YELLOW := Color(0.9, 0.9,  0.50)
	const GREEN  := Color(0.35, 1.0, 0.50)
	const ORANGE := Color(1.0, 0.65, 0.20)

	if not r.word_order_ok:
		r.grammar_penalty = PENALTY_WRONG_GRAMMAR
		r.feedback_lines.append({"text": "✗ Verb must come FIRST!",      "color": RED})
		r.feedback_lines.append({"text": "→ " + r.example_sentence,      "color": YELLOW})
	elif not r.grammar_ok:
		r.grammar_penalty = PENALTY_WRONG_GRAMMAR
		if sentence.size() < min_cards:
			r.feedback_lines.append({"text": "✗ Need %d cards minimum!" % min_cards, "color": RED})
		elif not has_noun and stype != "basic":
			r.feedback_lines.append({"text": "✗ Missing a Noun!",                     "color": RED})
		elif not has_pronoun and min_cards >= 3:
			r.feedback_lines.append({"text": "✗ Missing a Pronoun (Aku/Ika/Ya)!",   "color": RED})
		else:
			r.feedback_lines.append({"text": "✗ Wrong sentence structure!",         "color": RED})
		r.feedback_lines.append({"text": "→ Try: " + r.example_sentence,             "color": YELLOW})
	else:
		match r.focus_type:
			"Actor":  r.feedback_lines.append({"text": "✓ Actor Focus!  (Verb + Pronoun + Noun)", "color": GREEN})
			"Object": r.feedback_lines.append({"text": "✓ Object Focus! (Verb + Noun + Pronoun)", "color": GREEN})

	# Affix check
	for card in sentence:
		if card.category in ["Affix", "Prefix", "Suffix", "Connector"]:
			r.has_affix = true
			break
	if not r.has_affix:
		r.affix_penalty = PENALTY_NO_AFFIX
		r.feedback_lines.append({"text": "No affixes  −10% DMG", "color": ORANGE})
	else:
		r.feedback_lines.append({"text": "✓ Affixes used!", "color": GREEN})

	r.total_multiplier = max(0.40, 1.0 - r.grammar_penalty - r.affix_penalty)
	return r

# ═══════════════════════════════════════════════════════
#  Damage calculation
# ═══════════════════════════════════════════════════════
func calculate_damage(quality: Dictionary) -> int:
	if not current_skill.is_damage_skill(): return 0
	var raw := int(current_character.get_actual_attack() * current_skill.get_actual_multiplier())

	# Talent bonus
	var talent := current_character.talent as SkillData
	if talent and talent.trigger_effect == "DamageBoost":
		for card in sentence:
			if card.category == talent.trigger_card_category or card.card_type == talent.trigger_card_type:
				raw = int(raw * (1.0 + talent.trigger_value))
				break

	# Active buff
	if active_buffs.has(current_character):
		raw = int(raw * (1.0 + active_buffs[current_character].get("atk_bonus", 0.0)))

	# Elemental bonus
	if current_skill.element == current_character.element:
		raw = int(raw * (1.0 + current_character.elemental_bonus))

	raw = int(raw * quality.total_multiplier)

	# Crit
	if randf() < current_character.crit_rate:
		raw = int(raw * current_character.crit_damage)
		print("CRITICAL!")

	return raw

# ═══════════════════════════════════════════════════════
#  Deal damage
# ═══════════════════════════════════════════════════════
func deal_damage(raw: int, idx: int) -> int:
	if idx >= enemies.size() or raw <= 0: return 0
	var target = enemies[idx]

	var def_red: float = active_debuffs.get(target, {}).get("def_reduction", 0.0)
	var eff_def: int = int(target.data.get_actual_defense() * (1.0 - def_red))
	var actual:  int = max(1, raw - int(eff_def * DEF_SCALAR))
	var dealt:   int = 0
	var sp:      Vector2 = _enemy_sp(idx)

	if target.is_shield_active:
		if current_skill.element == target.data.shield_element:
			target.current_shield_hp -= actual
			if target.current_shield_hp <= 0:
				var overflow: int = abs(target.current_shield_hp)
				target.current_shield_hp  = 0
				target.is_shield_active   = false
				target.current_hp        -= overflow
				dealt                     = overflow
				await _shatter_shield(idx)
				_show_floating_text("BREAK!",        Color(1.0, 0.8,  0.0), sp)
				_show_floating_text(str(overflow),   Color(1.0, 0.95, 0.3), sp + Vector2(0, -35))
			else:
				_show_floating_text("%d ⬡" % actual, Color(0.5, 0.8,  1.0), sp)
		else:
			target.current_hp -= actual
			dealt               = actual
			_show_floating_text(str(actual),         Color(1.0, 0.95, 0.3), sp)
	else:
		target.current_hp -= actual
		dealt               = actual
		_show_floating_text(str(actual),             Color(1.0, 0.95, 0.3), sp)

	_update_enemy_ui(idx)

	if target.current_hp <= 0:
		_give_energy_action(current_character, ENERGY_FROM_KILL)
		await _on_enemy_defeated(idx)

	return dealt


func _enemy_sp(idx: int) -> Vector2:
	if not camera: return Vector2(400, 200)
	return camera.unproject_position(_get_enemy_pos(idx) + Vector3(0, 2.0, 0))

func _ally_screen_pos(char_idx: int) -> Vector2:
	if not camera: return Vector2(200, 300)
	return camera.unproject_position(_get_ally_pos(char_idx) + Vector3(0, 2.0, 0))

func _on_enemy_defeated(idx: int) -> void:
	if idx < enemy_ui_nodes.size():
		var ui = enemy_ui_nodes[idx]
		if ui and is_instance_valid(ui.root):
			var t := create_tween()
			t.tween_property(ui.root, "modulate:a", 0.0, 0.4)
			await t.finished
			ui.root.queue_free()
		enemy_ui_nodes.remove_at(idx)
	enemies.remove_at(idx)
	targeted_enemy_index = clamp(targeted_enemy_index, 0, max(0, enemies.size() - 1))
	_refresh_enemy_highlight()
	check_battle_end()

# ═══════════════════════════════════════════════════════
#  Skill effects
# ═══════════════════════════════════════════════════════
func resolve_skill_effects() -> void:
	if current_skill == null: return
	match current_skill.effect_type:
		"Buff":
			var targets := _get_buff_targets()
			for cd in targets:
				apply_buff(cd, current_skill.get_actual_effect_value(), current_skill.effect_duration)
		"Debuff":
			if enemies.size() > 0:
				apply_debuff(enemies[targeted_enemy_index],
					current_skill.get_actual_effect_value(), current_skill.effect_duration)
		"Heal":
			for i in _get_ally_target_indices():
				_apply_heal(i)
		"Shield":
			for i in _get_ally_target_indices():
				_apply_shield(i)


func _get_ally_target_indices() -> Array:
	if current_skill.is_aoe() or current_skill.target_type == "Team":
		return range(GameManager.player_party.size())
	return [targeted_ally_index]

func _get_buff_targets() -> Array:
	if current_skill.is_aoe() or current_skill.target_type == "Team":
		return GameManager.player_party
	return [GameManager.player_party[targeted_ally_index]]


func _apply_heal(char_idx: int) -> void:
	if char_idx >= GameManager.player_party.size(): return
	var cd:     CharacterData = GameManager.player_party[char_idx]
	var max_hp: float = float(cd.get_actual_hp())
	var heal:   float = float(current_skill.get_actual_heal_flat()) + max_hp * current_skill.get_actual_heal_scaling()
	character_hp[char_idx] = min(character_hp[char_idx] + heal, max_hp)
	_update_portrait_hp(char_idx)
	_show_floating_text("+%d HP" % int(heal), Color(0.3, 1.0, 0.5), _ally_screen_pos(char_idx))

func _apply_shield(char_idx: int) -> void:
	if char_idx >= GameManager.player_party.size(): return
	var shield_val := float(current_skill.get_actual_shield_flat()) + \
		float(current_character.get_actual_defense()) * current_skill.get_actual_shield_scaling()
	character_shields[char_idx] += shield_val
	_update_portrait_hp(char_idx)
	_show_floating_text("🛡 %d" % int(shield_val), Color(0.4, 0.7, 1.0), _ally_screen_pos(char_idx))

func apply_buff(target, atk_bonus: float, duration: int) -> void:
	active_buffs[target] = {"atk_bonus": atk_bonus, "turns_left": duration}

func apply_debuff(target, def_reduction: float, duration: int) -> void:
	active_debuffs[target] = {"def_reduction": def_reduction, "turns_left": duration}

func _tick_status_effects() -> void:
	for d in [active_buffs, active_debuffs]:
		var remove := []
		for key in d:
			d[key].turns_left -= 1
			if d[key].turns_left <= 0:
				remove.append(key)
		for k in remove:
			d.erase(k)

# ═══════════════════════════════════════════════════════
#  Floating text + damage display
# ═══════════════════════════════════════════════════════
func _show_floating_text(text: String, color: Color, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.scale = Vector2(0.5, 0.5) # Start small for juice
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color",         color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	$BattleUI.add_child(lbl)
	
	var t := create_tween()
	t.set_parallel(true)
	# HSR style damage pop
	t.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BOUNCE)
	t.tween_property(lbl, "position:y", pos.y - 80, 1.0).set_ease(Tween.EASE_OUT)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.6)
	fade_tween.tween_property(lbl, "modulate:a", 0.0, 0.4)
	
	await t.finished
	if is_instance_valid(lbl): lbl.queue_free()


func _show_turn_damage(amount: int) -> void:
	var old := get_node_or_null("BattleUI/TurnDmgLabel")
	if old: old.queue_free()

	var lbl := Label.new()
	lbl.name = "TurnDmgLabel"
	lbl.text = "%d DMG" % amount
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color",         Color(1.0, 0.95, 0.3))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lbl.offset_left              = -250.0
	lbl.offset_top               = 60.0
	lbl.offset_right             = -30.0
	lbl.offset_bottom            = 110.0
	lbl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_RIGHT
	$BattleUI.add_child(lbl)

	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(lbl): return
	var t := create_tween()
	t.tween_property(lbl, "modulate:a", 0.0, 0.4)
	await t.finished
	if is_instance_valid(lbl): lbl.queue_free()

# ═══════════════════════════════════════════════════════
#  Feedback popup
# ═══════════════════════════════════════════════════════
func show_feedback_popup(damage: int, quality: Dictionary) -> void:
	var existing := get_node_or_null("BattleUI/FeedbackPopup")
	if existing: existing.queue_free()

	var popup := PanelContainer.new()
	popup.name = "FeedbackPopup"
	var s := _make_rounded_stylebox(Color(0.08, 0.1, 0.15, 0.95), 16)
	s.border_width_left   = 2; s.border_width_right  = 2
	s.border_width_top    = 2; s.border_width_bottom = 2
	s.border_color        = Color(0.4, 0.5, 0.7, 0.8)
	s.shadow_color        = Color(0, 0, 0, 0.5)
	s.shadow_size         = 10
	popup.add_theme_stylebox_override("panel", s)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.size = Vector2(300, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	for cfg in [
		{"text": "⚔  Attack Result", "size": 18, "color": Color.WHITE},
		{"text": "%d DMG" % damage,   "size": 32, "color": Color(1.0, 0.95, 0.3)},
	]:
		var lbl := Label.new()
		lbl.text                 = cfg.text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", cfg.size)
		lbl.add_theme_color_override("font_color", cfg.color)
		vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())
	for line in quality.feedback_lines:
		var lbl := Label.new()
		lbl.text                 = line.text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", line.color)
		vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())

	var ml := Label.new()
	ml.text                 = "Sentence quality: %d%%" % int(quality.total_multiplier * 100)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.add_theme_font_size_override("font_size", 13)
	ml.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	vbox.add_child(ml)
	popup.add_child(vbox)
	
	popup.scale = Vector2(0.8, 0.8)
	$BattleUI.add_child(popup)
	create_tween().tween_property(popup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(popup): return
	var t := create_tween()
	t.tween_property(popup, "modulate:a", 0.0, 0.5)
	await t.finished
	if is_instance_valid(popup): popup.queue_free()

# ═══════════════════════════════════════════════════════
#  Enemy turn
# ═══════════════════════════════════════════════════════
func enemy_turn(entry: Dictionary) -> void:
	print(entry.data.enemy_name + " attacks!")
	await get_tree().create_timer(1.5).timeout
	if GameManager.player_party.is_empty():
		current_turn_index += 1
		process_next_turn()
		return

	var target_idx := randi() % GameManager.player_party.size()
	var cd:      CharacterData = GameManager.player_party[target_idx]
	var raw_dmg: int = entry.data.base_attack

	# Absorb with shield first
	if character_shields[target_idx] > 0.0:
		var absorbed: float = min(character_shields[target_idx], float(raw_dmg))
		character_shields[target_idx] -= absorbed
		raw_dmg -= int(absorbed)
		_show_floating_text("🛡 %d" % int(absorbed), Color(0.4, 0.7, 1.0), _ally_screen_pos(target_idx))

	if raw_dmg > 0:
		character_hp[target_idx] = max(0.0, character_hp[target_idx] - float(raw_dmg))
		_give_energy_hit_taken(cd)
		_show_floating_text(str(raw_dmg), Color(1.0, 0.3, 0.3), _ally_screen_pos(target_idx))
		
		# Screen shake on player hit
		if camera:
			var shake = create_tween()
			var og_pos = camera.position
			shake.tween_property(camera, "position", og_pos + Vector3(0.1, 0.1, 0), 0.05)
			shake.tween_property(camera, "position", og_pos - Vector3(0.1, 0.1, 0), 0.05)
			shake.tween_property(camera, "position", og_pos, 0.05)

	_update_portrait_hp(target_idx)

	if character_hp[target_idx] <= 0:
		print(cd.character_name + " has fallen!")
		if target_idx < portrait_containers.size() and is_instance_valid(portrait_containers[target_idx]):
			var t := create_tween()
			t.tween_property(portrait_containers[target_idx], "modulate:a", 0.3, 0.4)
		GameManager.player_party.remove_at(target_idx)
		character_hp.remove_at(target_idx)
		character_shields.remove_at(target_idx)
		turn_queue = turn_queue.filter(func(t):
			return t.type != "player" or GameManager.player_party.has(t.data)
		)
		check_battle_end()
		if enemies.is_empty() or GameManager.player_party.is_empty():
			return

	current_turn_index += 1
	process_next_turn()

# ═══════════════════════════════════════════════════════
#  Battle end
# ═══════════════════════════════════════════════════════
func check_battle_end() -> void:
	if enemies.is_empty():
		print("Victory!")
		await get_tree().create_timer(2.0).timeout
		await SupabaseManager.add_pulls(1)
		GameManager.end_combat()
		get_tree().change_scene_to_file(origin_scene)
	elif GameManager.player_party.is_empty():
		print("Defeat!")
		await get_tree().create_timer(2.0).timeout
		GameManager.end_combat()
		get_tree().change_scene_to_file(origin_scene)

# ═══════════════════════════════════════════════════════
#  Turn order UI
# ═══════════════════════════════════════════════════════
func update_turn_order_ui() -> void:
	for child in turn_order_ui.get_children(): 
		child.queue_free()
	
	var panel = PanelContainer.new()
	var ps = _make_rounded_stylebox(Color(0.12, 0.13, 0.18, 0.85), 8)
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.border_color = Color(0.3, 0.35, 0.5, 0.5)
	ps.content_margin_left = 12; ps.content_margin_right = 12
	ps.content_margin_top = 8; ps.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", ps)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "TURN ORDER"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	
	for i in range(min(5, turn_queue.size())):
		var idx  := (current_turn_index + i) % turn_queue.size()
		var turn: Dictionary = turn_queue[idx]
		var lbl  := Label.new()
		lbl.text = turn.data.character_name if turn.type == "player" \
			else turn.data.data.enemy_name
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		if i == 0:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)) # HSR Gold
			
		vbox.add_child(lbl)
		
	turn_order_ui.add_child(panel)

# ═══════════════════════════════════════════════════════
#  SP display
# ═══════════════════════════════════════════════════════
func _update_sp_display() -> void:
	# OPTIMIZED: Initialize the star nodes only if they don't exist yet to prevent node-recreation lag spikes
	if sp_stars.get_child_count() == 0:
		for i in range(max_sp):
			var star := Label.new()
			star.add_theme_font_size_override("font_size", 28)
			star.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			star.add_theme_constant_override("shadow_offset_x", 2)
			star.add_theme_constant_override("shadow_offset_y", 2)
			if not sp_stars is BoxContainer:
				star.position = Vector2(i * 22, 0)
			sp_stars.add_child(star)

	# Update the state of the existing stars
	var index = 0
	for star in sp_stars.get_children():
		if index < current_sp:
			star.text = "★"
			star.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
		else:
			star.text = "☆"
			star.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		index += 1

# ═══════════════════════════════════════════════════════
#  Battle sprites
# ═══════════════════════════════════════════════════════
func _setup_battle_sprites() -> void:
	for child in $Background.get_children():
		if child.name.begins_with("player_") or child.name.begins_with("enemy_") \
				or child.name.begins_with("Placeholder_"):
			child.queue_free()
	for i in range(GameManager.player_party.size()):
		_spawn_character(GameManager.player_party[i], i)
	for i in range(enemies.size()):
		_spawn_enemy_sprite(i)
	_build_enemy_ui()
	targeted_enemy_index = 0
	_refresh_enemy_highlight()

func _enable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if node is SpriteBase3D: # Ensure Sprites with transparency have shadows that trace their shapes properly
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	for child in node.get_children():
		_enable_shadows(child)

func _spawn_character(data: CharacterData, idx: int) -> void:
	var scene_path := "res://Characters/%s.tscn" % data.character_name.to_lower()
	var scene      := load(scene_path) if ResourceLoader.exists(scene_path) else null
	if scene == null:
		_create_placeholder(data, idx)
		return
	var inst = scene.instantiate()
	if inst.has_method("setup"): inst.setup(data, "player")
	inst.scale    = Vector3(4.0, 4.0, 4.0)
	inst.position = _get_ally_pos(idx)
	inst.name     = "player_" + data.character_name
	
	# Enable shadows recursively for the character mesh or sprites inside the instantiated scene
	_enable_shadows(inst)
	
	$Background.add_child(inst)

func _spawn_enemy_sprite(idx: int) -> void:
	var data: EnemyData = enemies[idx].data
	var sprite          := AnimatedSprite3D.new()
	sprite.name         = "enemy_sprite_" + str(idx)
	sprite.position     = _get_enemy_pos(idx)
	sprite.scale        = Vector3(5.0, 5.0, 1.0)
	sprite.pixel_size   = 0.01

	# Shadows enabled for 2D sprites in 3D 
	sprite.cast_shadow  = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.alpha_cut    = SpriteBase3D.ALPHA_CUT_DISCARD

	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
	else:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.2, 0.2))
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", ImageTexture.create_from_image(img))
		sprite.sprite_frames = frames

	sprite.animation = "idle"
	sprite.play()
	$Background.add_child(sprite)


func _create_placeholder(data: CharacterData, idx: int) -> void:
	var sprite      := AnimatedSprite3D.new()
	sprite.name     = "player_" + data.character_name
	sprite.position = _get_ally_pos(idx)
	sprite.scale    = Vector3(5.0, 5.0, 1.0)
	sprite.pixel_size = 0.01
	
	# Shadows enabled for 2D sprites in 3D
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.alpha_cut   = SpriteBase3D.ALPHA_CUT_DISCARD

	if data.splash_art:
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", data.splash_art)
		sprite.sprite_frames = frames
	else:
		const ELEMENT_COLORS := {
			"Water": Color(0.2, 0.4, 0.9),
			"Fire":  Color(0.9, 0.3, 0.1),
			"Earth": Color(0.6, 0.4, 0.2),
			"Wind":  Color(0.2, 0.8, 0.4),
		}
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(ELEMENT_COLORS.get(data.element, Color(0.5, 0.5, 0.5)))
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", ImageTexture.create_from_image(img))
		sprite.sprite_frames = frames

	sprite.animation = "idle"
	$Background.add_child(sprite)
