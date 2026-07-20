extends Control

# ─── Element & stat colour palettes ──────────────────────────────────────────
const ELEMENT_COLORS: Dictionary = {
	"Water":     Color(0.25, 0.50, 0.95),
	"Wind":      Color(0.20, 0.85, 0.50),
	"Fire":      Color(0.95, 0.35, 0.12),
	"Earth":     Color(0.70, 0.52, 0.25),
	"Ice":       Color(0.55, 0.85, 0.95),
	"Lightning": Color(0.70, 0.40, 0.95),
	"Quantum":   Color(0.40, 0.30, 0.82),
}

# ─── Node References ──────────────────────────────────────────────────────────
# TopBar — restructured into TitleRow / RosterRow
@onready var close_btn        = $MarginContainer/MainLayout/TopBar/TitleRow/CloseButton
@onready var roster_container = $MarginContainer/MainLayout/TopBar/RosterRow/RosterScroll/CharacterRoster

# Center
@onready var char_sprite      = $MarginContainer/MainLayout/ContentSplit/CenterArt/CharacterSprite

# Right panel
@onready var element_accent   = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/ElementAccent
@onready var right_name_label = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/NameLabel
@onready var path_element_label = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/PathElement
@onready var level_value      = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/LevelLabel
@onready var exp_bar          = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/ExpBar
@onready var exp_value_label  = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/ExpValueLabel
@onready var return_btn       = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/ReturnBtn

@onready var stat_atk     = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatATK/Value
@onready var stat_hp      = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatHP/Value
@onready var stat_def     = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatDEF/Value
@onready var stat_spd     = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatSPD/Value
@onready var stat_crit    = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatCRIT/Value
@onready var stat_critdmg = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatCRITDMG/Value

# ─── State ───────────────────────────────────────────────────────────────────
var all_characters: Array[CharacterData] = []
var current_selected_char_id: int = -1

var style_normal: StyleBoxFlat
var style_active: StyleBoxFlat

# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_create_dynamic_styles()
	_animate_in()

	close_btn.pressed.connect(_on_close_pressed)
	if is_instance_valid(return_btn):
		return_btn.pressed.connect(_on_close_pressed)

	if CharacterManager.has_signal("characters_updated"):
		if not CharacterManager.characters_updated.is_connected(refresh_character_data):
			CharacterManager.characters_updated.connect(refresh_character_data)

	refresh_character_data()

	if SupabaseManager.has_method("fetch_player_characters"):
		SupabaseManager.fetch_player_characters()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

# ─── Enter / exit animations ─────────────────────────────────────────────────
func _animate_in() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.28)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _animate_out(callback: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	callback.call()

# ─── Dynamic roster button styles ────────────────────────────────────────────
func _create_dynamic_styles() -> void:
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.09, 0.11, 0.17, 0.75)
	style_normal.border_width_left   = 1
	style_normal.border_width_top    = 1
	style_normal.border_width_right  = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.35, 0.40, 0.52, 0.25)
	style_normal.set_corner_radius_all(32)

	style_active = StyleBoxFlat.new()
	style_active.bg_color = Color(0.12, 0.16, 0.25, 1)
	style_active.border_width_left   = 2
	style_active.border_width_top    = 2
	style_active.border_width_right  = 2
	style_active.border_width_bottom = 2
	style_active.border_color = Color(0.85, 0.75, 0.45, 1)
	style_active.set_corner_radius_all(32)
	style_active.shadow_color = Color(0.85, 0.75, 0.45, 0.25)
	style_active.shadow_size = 8

func _get_roster_style(is_active: bool) -> StyleBoxFlat:
	return style_active if is_active else style_normal

# ─── Data refresh ─────────────────────────────────────────────────────────────
func refresh_character_data() -> void:
	all_characters.clear()

	for db_char in CharacterManager.player_characters:
		var char_id = db_char.get("character_id", 0)
		var char_resource = CharacterManager.get_character_by_id(char_id)

		if char_resource:
			var instance = char_resource.duplicate()
			instance.current_level = db_char.get("current_level", 1)

			instance.set_meta("current_exp", db_char.get("current_exp", 0))
			instance.set_meta("max_exp",     db_char.get("max_exp", 1000))

			all_characters.append(instance)

	_populate_roster()

func _populate_roster() -> void:
	for child in roster_container.get_children():
		child.queue_free()

	for char_data in all_characters:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(68, 68)

		btn.add_theme_stylebox_override("normal", _get_roster_style(false))
		btn.add_theme_stylebox_override("hover",  style_active)

		if char_data.splash_art:
			btn.icon = char_data.splash_art
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
		else:
			btn.text = char_data.character_name.substr(0, 2).to_upper()
			btn.add_theme_font_size_override("font_size", 14)

		# FIX 1: Explicitly typed as Color
		var el_color: Color = ELEMENT_COLORS.get(char_data.element, Color.GRAY)
		btn.modulate = el_color.lerp(Color.WHITE, 0.45)

		btn.pressed.connect(_on_roster_button_pressed.bind(char_data))
		roster_container.add_child(btn)

	if all_characters.size() > 0:
		# FIX 2: Explicitly typed as CharacterData
		var to_display: CharacterData = all_characters[0]
		if current_selected_char_id != -1:
			for c in all_characters:
				if c.character_id == current_selected_char_id:
					to_display = c
					break
		_display_character(to_display)

func _on_roster_button_pressed(char_data: CharacterData) -> void:
	_display_character(char_data)

# ─── Display a character ──────────────────────────────────────────────────────
func _display_character(char_data: CharacterData) -> void:
	current_selected_char_id = char_data.character_id

	# Update roster active states
	var idx := 0
	for c in all_characters:
		if idx < roster_container.get_child_count():
			# FIX 3: Explicitly typed and casted to Button
			var btn: Button = roster_container.get_child(idx) as Button
			btn.add_theme_stylebox_override("normal", _get_roster_style(c.character_id == current_selected_char_id))
		idx += 1

	# Element colour — used for accent bar and path label tint
	# FIX 4: Explicitly typed as Color
	var el_color: Color = ELEMENT_COLORS.get(char_data.element, Color(0.85, 0.75, 0.45, 1))
	element_accent.color = el_color

	# Text fields
	right_name_label.text = char_data.character_name
	path_element_label.text = "%s  ·  %s" % [char_data.element, char_data.job]
	path_element_label.add_theme_color_override("font_color", el_color.lerp(Color(0.75, 0.82, 0.95), 0.45))
	level_value.text = "Lv. %d / %d" % [char_data.current_level, char_data.max_level]

	# EXP bar
	if char_data.has_meta("current_exp") and char_data.has_meta("max_exp"):
		var cur_exp: int = char_data.get_meta("current_exp")
		var max_exp: int = char_data.get_meta("max_exp")
		exp_bar.max_value = max_exp
		exp_bar.value     = cur_exp
		if is_instance_valid(exp_value_label):
			exp_value_label.text = "%d / %d  EXP" % [cur_exp, max_exp]
	else:
		exp_bar.max_value = 100
		exp_bar.value     = 0
		if is_instance_valid(exp_value_label):
			exp_value_label.text = "0 / 0  EXP"

	# Stats — values only; colours are set in the TSCN per-label
	stat_atk.text     = str(char_data.get_actual_attack())
	stat_hp.text      = str(char_data.get_actual_hp())
	stat_def.text     = str(char_data.get_actual_defense())
	stat_spd.text     = str(char_data.speed)
	stat_crit.text    = "%.1f%%" % (char_data.crit_rate * 100.0)
	stat_critdmg.text = "%.1f%%" % (char_data.crit_damage * 100.0)

	# Character art
	if char_data.splash_art:
		char_sprite.texture  = char_data.splash_art
		char_sprite.modulate = Color.WHITE
	else:
		char_sprite.texture  = null
		char_sprite.modulate = el_color.lerp(Color.WHITE, 0.30)

# ─── Close / return ──────────────────────────────────────────────────────────
func _on_close_pressed() -> void:
	_animate_out(func():
		if GameManager.has_meta("return_scene"):
			GameManager.pending_zone = GameManager.get_meta("return_scene")
			get_tree().change_scene_to_file("res://Scenes/Game.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	)
