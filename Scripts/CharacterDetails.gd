extends Control

const ELEMENT_COLORS: Dictionary = {
	"Water": Color(0.2, 0.4, 0.9),
	"Wind": Color(0.2, 0.8, 0.4),
	"Fire": Color(0.9, 0.3, 0.1),
	"Earth": Color(0.6, 0.4, 0.2)
}

# --- Node References ---
@onready var close_btn = $MarginContainer/MainLayout/TopBar/CloseButton
@onready var return_btn = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/ReturnBtn
@onready var roster_container = $MarginContainer/MainLayout/TopBar/RosterScroll/CharacterRoster

# Left Panel
@onready var element_label = $MarginContainer/MainLayout/ContentSplit/LeftNavBG/LeftNavMargin/LeftNav/Element
@onready var path_label = $MarginContainer/MainLayout/ContentSplit/LeftNavBG/LeftNavMargin/LeftNav/Path

# Center Panel
@onready var char_sprite = $MarginContainer/MainLayout/ContentSplit/CenterArt/CharacterSprite

# Right Panel (Stats)
@onready var right_name_label = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/NameLabel
@onready var path_element_label = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/PathElement
@onready var level_value = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/LevelLabel
@onready var exp_bar = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/ExpBar

@onready var stat_atk = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatATK/Value
@onready var stat_hp = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatHP/Value
@onready var stat_def = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatDEF/Value
@onready var stat_spd = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatSPD/Value
@onready var stat_crit = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatCRIT/Value
@onready var stat_critdmg = $MarginContainer/MainLayout/ContentSplit/RightStats/Margin/VBox/StatCRITDMG/Value

var all_characters: Array[CharacterData] = []
var current_selected_char_id: int = -1

# Premium Button Styles
var style_normal: StyleBoxFlat
var style_active: StyleBoxFlat

func _ready():
	_create_dynamic_styles()
	
	close_btn.pressed.connect(_on_close_pressed)
	# Safely connect return button if it exists in your specific tscn
	if return_btn:
		return_btn.pressed.connect(_on_close_pressed)
	
	# Listen for global updates
	if GameManager.has_signal("characters_updated"):
		if not GameManager.characters_updated.is_connected(refresh_character_data):
			GameManager.characters_updated.connect(refresh_character_data)
	
	refresh_character_data()
	
	if SupabaseManager.has_method("fetch_player_characters"):
		SupabaseManager.fetch_player_characters()

# --- NEW: Listens for the Escape Key ---
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func _create_dynamic_styles() -> void:
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.12, 0.18, 1)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.4, 0.4, 0.5, 1)
	style_normal.set_corner_radius_all(32)

	style_active = StyleBoxFlat.new()
	style_active.bg_color = Color(0.15, 0.2, 0.3, 1)
	style_active.border_width_left = 2
	style_active.border_width_top = 2
	style_active.border_width_right = 2
	style_active.border_width_bottom = 2
	style_active.border_color = Color(0.85, 0.75, 0.45, 1)
	style_active.set_corner_radius_all(32)

func _get_roster_style(is_active: bool) -> StyleBoxFlat:
	return style_active if is_active else style_normal

func refresh_character_data() -> void:
	all_characters.clear()
	
	for db_char in GameManager.player_characters:
		var char_id = db_char.get("character_id", 0)
		var char_resource = GameManager.get_character_by_id(char_id)
		
		if char_resource:
			var instance = char_resource.duplicate()
			instance.current_level = db_char.get("current_level", 1)
			
			var current_exp = db_char.get("current_exp", 0)
			var max_exp = db_char.get("max_exp", 1000) 
			
			instance.set_meta("current_exp", current_exp)
			instance.set_meta("max_exp", max_exp)
			
			all_characters.append(instance)

	_populate_roster()

func _populate_roster() -> void:
	for child in roster_container.get_children():
		child.queue_free()
		
	for char_data in all_characters:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		
		btn.add_theme_stylebox_override("normal", _get_roster_style(false))
		btn.add_theme_stylebox_override("hover", _get_roster_style(false))
		
		if char_data.splash_art:
			btn.icon = char_data.splash_art
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
		else:
			btn.text = char_data.character_name.substr(0, 2).to_upper() 
			
		var el_color = ELEMENT_COLORS.get(char_data.element, Color.GRAY)
		btn.modulate = el_color.lerp(Color.WHITE, 0.5) 
		
		btn.pressed.connect(_on_roster_button_pressed.bind(char_data))
		roster_container.add_child(btn)
		
	if all_characters.size() > 0:
		var to_display = all_characters[0]
		if current_selected_char_id != -1:
			for c in all_characters:
				if c.character_id == current_selected_char_id:
					to_display = c
					break
		_display_character(to_display)

func _on_roster_button_pressed(char_data: CharacterData) -> void:
	_display_character(char_data)

func _display_character(char_data: CharacterData) -> void:
	current_selected_char_id = char_data.character_id
	
	var idx = 0
	for c in all_characters:
		if idx < roster_container.get_child_count():
			var btn = roster_container.get_child(idx)
			var is_active = (c.character_id == current_selected_char_id)
			btn.add_theme_stylebox_override("normal", _get_roster_style(is_active))
			btn.add_theme_stylebox_override("hover", _get_roster_style(is_active))
		idx += 1
	
	right_name_label.text = char_data.character_name
	path_element_label.text = "%s / %s" % [char_data.element, char_data.job]
	level_value.text = "Lv. %d/%d" % [char_data.current_level, char_data.max_level]
	
	if char_data.has_meta("current_exp") and char_data.has_meta("max_exp"):
		exp_bar.max_value = char_data.get_meta("max_exp")
		exp_bar.value = char_data.get_meta("current_exp")
	else:
		exp_bar.max_value = 100
		exp_bar.value = 0
	
	stat_atk.text = "+ " + str(char_data.get_actual_attack())
	stat_hp.text = "+ " + str(char_data.get_actual_hp())
	stat_def.text = "+ " + str(char_data.get_actual_defense())
	stat_spd.text = "  " + str(char_data.speed)
	stat_crit.text = "+ %.1f%%" % (char_data.crit_rate * 100.0)
	stat_critdmg.text = "+ %.1f%%" % (char_data.crit_damage * 100.0)
	
	if char_data.splash_art:
		char_sprite.texture = char_data.splash_art
		char_sprite.modulate = Color.WHITE
	else:
		char_sprite.texture = null
		char_sprite.modulate = ELEMENT_COLORS.get(char_data.element, Color.GRAY)

func _on_close_pressed():
	if GameManager.has_meta("return_scene"):
		var prev_scene = GameManager.get_meta("return_scene")
		get_tree().change_scene_to_file(prev_scene)
	else:
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
