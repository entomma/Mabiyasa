extends Control
class_name BattleCard

signal card_selected(card_data: WordCard)

@export var card_data: WordCard:
	set(value):
		card_data = value
		if is_node_ready():
			update_display()

# Don't use @onready with direct paths - use find_child instead
var background: TextureRect
var art_texture: TextureRect
var kapampangan_label: Label
var english_label: Label
var example_label: Label
var type_label: Label
var button: Button

func _ready():
	# Find nodes by name (works even if they're nested)
	background = find_child("Background", true, false)
	art_texture = find_child("ArtTexture", true, false)
	kapampangan_label = find_child("KapampanganLabel", true, false)
	english_label = find_child("EnglishLabel", true, false)
	example_label = find_child("ExampleLabel", true, false)
	type_label = find_child("TypeLabel", true, false)
	button = find_child("Button", true, false)
	
	# Debug: print what we found
	print("Card nodes found:")
	print("  Background: ", background)
	print("  ArtTexture: ", art_texture)
	print("  KapampanganLabel: ", kapampangan_label)
	print("  EnglishLabel: ", english_label)
	print("  ExampleLabel: ", example_label)
	print("  TypeLabel: ", type_label)
	print("  Button: ", button)
	
	if button:
		button.pressed.connect(_on_button_pressed)
		button.flat = true
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	update_display()

func update_display():
	if not card_data:
		return
	
	# Safety checks for missing nodes
	if not background:
		print("ERROR: Background node not found")
		return
	
	var bg_path = ""
	match card_data.card_type:
		"Noun":
			bg_path = "res://assets/cards/noun_bg.png"
		"Action":
			bg_path = "res://assets/cards/verb_bg.png"
		"Adjective":
			bg_path = "res://assets/cards/adjective_bg.png"
		_:
			bg_path = "res://assets/cards/default_bg.png"
	
	if ResourceLoader.exists(bg_path):
		background.texture = load(bg_path)
	
	if art_texture and card_data.texture:
		art_texture.texture = card_data.texture
	
	if kapampangan_label:
		kapampangan_label.text = card_data.kapampangan_text
	if english_label:
		english_label.text = card_data.english_hint
	if example_label:
		example_label.text = card_data.example_sentence
	if type_label:
		type_label.text = card_data.card_type

func _on_button_pressed():
	card_selected.emit(card_data)

func set_highlight(enabled: bool):
	modulate = Color(1.2, 1.2, 0.8) if enabled else Color(1, 1, 1)
