extends Control
class_name BattleCard

signal card_selected(card_data: WordCard)

@export var card_data: WordCard:
	set(value):
		card_data = value
		if is_node_ready():
			update_display()

# ═══════════════════════════════════════════════════════
#  UI References
# ═══════════════════════════════════════════════════════
@onready var bg_panel = $CardBg
@onready var active_outline = $ActiveOutline
@onready var type_panel = $CardBg/Margin/VBox/Header/TypePanel
@onready var type_label = $CardBg/Margin/VBox/Header/TypePanel/Margin/TypeLabel
@onready var art_texture = $CardBg/Margin/VBox/ArtTexture
@onready var kapampangan_label = $CardBg/Margin/VBox/Titles/KapampanganLabel
@onready var english_label = $CardBg/Margin/VBox/Titles/EnglishLabel
@onready var example_label = $CardBg/Margin/VBox/ExampleLabel
@onready var click_btn = $ClickButton

var is_selected := false

# Matches the colors used in your Battle.gd UI
const TYPE_COLORS = {
	"Action": Color(0.85, 0.35, 0.28),
	"Noun": Color(0.20, 0.50, 0.85),
	"Number": Color(0.20, 0.75, 0.40),
	"Adjective": Color(0.75, 0.50, 0.85),
	"Pronoun": Color(0.90, 0.60, 0.10)
}

func _ready():
	# Connect interaction signals
	click_btn.pressed.connect(_on_button_pressed)
	click_btn.mouse_entered.connect(_on_hover.bind(true))
	click_btn.mouse_exited.connect(_on_hover.bind(false))
	
	# Hide the glow outline by default
	active_outline.modulate.a = 0.0
	
	update_display()

func update_display():
	if not card_data:
		return
	
	# 1. Update Text
	kapampangan_label.text = card_data.kapampangan_text
	english_label.text = card_data.english_hint
	type_label.text = card_data.card_type.to_upper()
	
	# If your WordCard resource has an example variable, you can assign it here:
	# example_label.text = '\"' + card_data.example_sentence + '\"'
	example_label.text = "" # Default to empty if none exists
	
	# 2. Update Art
	if "texture" in card_data and card_data.texture:
		art_texture.texture = card_data.texture
	else:
		art_texture.texture = null
		
	# 3. Dynamic Coloring based on Card Type
	var type_color = TYPE_COLORS.get(card_data.card_type, Color(0.5, 0.5, 0.5))
	
	# Color the top-right Pill shape
	var pill_style = type_panel.get_theme_stylebox("panel").duplicate()
	pill_style.bg_color = type_color
	type_panel.add_theme_stylebox_override("panel", pill_style)
	
	# Color the Selection Glow
	var outline_style = active_outline.get_theme_stylebox("panel").duplicate()
	outline_style.border_color = type_color.lightened(0.3)
	outline_style.shadow_color = type_color
	active_outline.add_theme_stylebox_override("panel", outline_style)

# ═══════════════════════════════════════════════════════
#  Animations & Interactions
# ═══════════════════════════════════════════════════════
func _on_hover(is_hovered: bool):
	if is_selected:
		return # Don't shrink if it's currently selected in the sentence
		
	var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hovered:
		t.tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)
	else:
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func set_highlight(active: bool):
	is_selected = active
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if active:
		# Pop up and turn on the colored glow
		t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.2)
		t.tween_property(active_outline, "modulate:a", 1.0, 0.15)
	else:
		# Return to normal
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
		t.tween_property(active_outline, "modulate:a", 0.0, 0.15)

func _on_button_pressed():
	card_selected.emit(card_data)
