extends Control

# Core cinematic processing phases
enum State { TYPING, SHOWING_TEXT, FADING_OUT_TEXT, FADING_IN_IMAGE, SHOWING_IMAGE, FADING_OUT_IMAGE }
var current_state: State = State.TYPING

# --- CONFIGURATION ---
@export var intro_slides: Array[Dictionary] = [
	{
		"text": "[center]Beyond the mist-shrouded valleys lies the ancient cradle of life...\n[color=gold]The Great Bundok[/color].[/center]"
	},
	{
		"image_path": "res://Assets/BUNDOK.png"
	},
	{
		"text": "[center]Here, the ancestors thrived by the rivers, passing down the sacred art of [color=cyan]Fishing[/color] and survival.[/center]"
	},
	{
		"image_path": "res://Assets/FISHING.png"
	}
]

@export var next_scene_path: String = "res://Scenes/MainMenu.tscn"
@export var typewriter_speed: float = 0.04
@export var fade_speed: float = 0.6

# --- NODE REFERENCES ---
@onready var story_label: RichTextLabel = $TextMargin/StoryLabel
@onready var story_image: TextureRect = $StoryImage

# --- INTERNAL STATE ---
var current_index: int = 0
var active_tween: Tween = null

func _ready() -> void:
	if intro_slides.is_empty():
		_transition_to_game()
		return
		
	# Ensure scene elements start completely hidden
	story_label.text = ""
	story_label.modulate.a = 0.0
	story_image.texture = null
	story_image.modulate.a = 0.0
	
	_load_current_step()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_handle_player_click()

func _load_current_step() -> void:
	var data = intro_slides[current_index]
	
	# Handle a TEXT timeline block
	if data.has("text") and data["text"] != "":
		story_label.text = data["text"]
		story_label.visible_characters = 0
		story_label.modulate.a = 1.0
		current_state = State.TYPING
		
		var raw_text_length = story_label.get_parsed_text().length()
		var duration = raw_text_length * typewriter_speed
		
		if active_tween: active_tween.kill()
		active_tween = create_tween()
		active_tween.tween_property(story_label, "visible_characters", raw_text_length, duration)
		active_tween.finished.connect(func():
			if current_state == State.TYPING:
				current_state = State.SHOWING_TEXT
		)
		
	# Handle an IMAGE timeline block
	elif data.has("image_path") and data["image_path"] != "":
		story_image.texture = load(data["image_path"])
		story_image.modulate.a = 0.0
		current_state = State.FADING_IN_IMAGE
		
		if active_tween: active_tween.kill()
		active_tween = create_tween()
		active_tween.tween_property(story_image, "modulate:a", 1.0, fade_speed)
		active_tween.finished.connect(func():
			if current_state == State.FADING_IN_IMAGE:
				current_state = State.SHOWING_IMAGE
		)
	else:
		# Fallback safety handler for misformatted steps
		_advance_timeline()

func _handle_player_click() -> void:
	match current_state:
		State.TYPING:
			# [Case 1 Intercept] Dialogue is crawl-typing -> stop animation and present all text to read
			if active_tween: active_tween.kill()
			story_label.visible_characters = story_label.get_parsed_text().length()
			current_state = State.SHOWING_TEXT
			
		State.SHOWING_TEXT:
			# [Case 2 / Follow-up click] Text is finished -> transition cleanly out to black
			current_state = State.FADING_OUT_TEXT
			if active_tween: active_tween.kill()
			active_tween = create_tween()
			active_tween.tween_property(story_label, "modulate:a", 0.0, fade_speed)
			active_tween.finished.connect(_advance_timeline)
			
		State.FADING_OUT_TEXT:
			# Catch rapid player input during fade -> clear instantly and execute next stage
			if active_tween: active_tween.kill()
			story_label.modulate.a = 0.0
			_advance_timeline()
			
		State.FADING_IN_IMAGE:
			# Bypass image blend animation -> force maximum opacity view instantly
			if active_tween: active_tween.kill()
			story_image.modulate.a = 1.0
			current_state = State.SHOWING_IMAGE
			
		State.SHOWING_IMAGE:
			# Image inspection over -> clear layout background cleanly
			current_state = State.FADING_OUT_IMAGE
			if active_tween: active_tween.kill()
			active_tween = create_tween()
			active_tween.tween_property(story_image, "modulate:a", 0.0, fade_speed)
			active_tween.finished.connect(_advance_timeline)
			
		State.FADING_OUT_IMAGE:
			# Catch rapid input during asset fade down
			if active_tween: active_tween.kill()
			story_image.modulate.a = 0.0
			_advance_timeline()

func _advance_timeline() -> void:
	current_index += 1
	if current_index >= intro_slides.size():
		_transition_to_game()
	else:
		_load_current_step()

func _transition_to_game() -> void:
	set_process_input(false)
	get_tree().change_scene_to_file(next_scene_path)
