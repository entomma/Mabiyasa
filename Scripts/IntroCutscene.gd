extends Control

# Core cinematic processing phases including Video support
enum State { 
	TYPING, SHOWING_TEXT, FADING_OUT_TEXT, 
	FADING_IN_IMAGE, SHOWING_IMAGE, FADING_OUT_IMAGE,
	FADING_IN_VIDEO, PLAYING_VIDEO, FADING_OUT_VIDEO 
}
var current_state: State = State.TYPING

# --- CONFIGURATION ---
@export var bgm_path: String = "res://Assets/intro_music.mp3"
@export var next_scene_path: String = "res://Scenes/Game.tscn"
@export var typewriter_speed: float = 0.04
@export var fade_speed: float = 0.6

# --- ADMIN / DEBUG CONFIGURATION ---
@export var enable_admin_skip: bool = true

@export var intro_slides: Array[Dictionary] = [
	{
		"text": "[center]Long ago, every living being spoke its own language.\nHumans, animals, and nature each carried voices of their own.[/center]"
	},
	{
		"image_path": "res://Assets/BUNDOK.png"
	},
	{
		"text": "[center]Though different, these languages shaped countless cultures, traditions, and ways of life.\nYet where understanding failed... conflict often followed.[/center]"
	},
	{
		"image_path": "res://Assets/FISHING.png"
	},
	{
		"text": "[center]Believing language to be the world's greatest barrier,\na faction of scientists sought to unite every voice into one.[/center]"
	},
	{
		"video_path": "res://Assets/ispid.ogv"
	},
	{
		"text": "[center]Their dream promised peace.\nA world where humans and animals could finally understand one another.[/center]"
	},
	{
		"image_path": "res://Assets/FISHING.png"
	},
	{
		"text": "[center]But language is more than words.\nIt carries memories, identity, and the history of every living being.[/center]"
	},
	{
		"image_path": "res://Assets/BUNDOK.png"
	},
	{
		"text": "[center]The experiment did not unite the world.\nIt changed it.[/center]"
	},
	{
		"video_path": "res://Assets/speedvid.ogv"
	},
	{
		"text": "[center]Far from the laboratories and the growing chaos...\nOne young fisherman began another ordinary morning,\nunaware that fate would soon call upon him.[/center]"
	}
]

# --- NODE REFERENCES ---
@onready var story_label: RichTextLabel = $TextMargin/StoryLabel
@onready var story_image: TextureRect = $StoryImage
@onready var story_video: VideoStreamPlayer = $StoryVideo
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

# --- INTERNAL STATE ---
var current_index: int = 0
var active_tween: Tween = null
var is_transitioning: bool = false

func _ready() -> void:
	if intro_slides.is_empty():
		_transition_to_game()
		return
		
	story_label.text = ""
	story_label.modulate.a = 0.0
	story_image.texture = null
	story_image.modulate.a = 0.0
	story_video.stream = null
	story_video.modulate.a = 0.0
	
	story_video.finished.connect(_on_video_finished)
	
	if bgm_path != "" and FileAccess.file_exists(bgm_path):
		bgm_player.stream = load(bgm_path)
		bgm_player.volume_db = 0.0
		bgm_player.play()
	
	_load_current_step()

func _input(event: InputEvent) -> void:
	if is_transitioning:
		return

	# --- ADMIN SKIP CHECK ---
	if enable_admin_skip and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE)):
		get_viewport().set_input_as_handled()
		_admin_skip_cinematic()
		return

	# --- REGULAR PLAYER CLICK/ADVANCE ---
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_handle_player_click()

func _admin_skip_cinematic() -> void:
	# Kill active animations and stop media
	if active_tween and active_tween.is_running():
		active_tween.kill()

	if story_video and story_video.is_playing():
		story_video.stop()

	# Immediately jump to game scene transition
	_transition_to_game()

func _load_current_step() -> void:
	if is_transitioning:
		return

	var data = intro_slides[current_index]
	
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
		
	elif data.has("video_path") and data["video_path"] != "":
		story_video.stream = load(data["video_path"])
		story_video.modulate.a = 0.0
		current_state = State.FADING_IN_VIDEO
		
		story_video.play()
		
		if active_tween: active_tween.kill()
		active_tween = create_tween()
		active_tween.tween_property(story_video, "modulate:a", 1.0, fade_speed)
		active_tween.finished.connect(func():
			if current_state == State.FADING_IN_VIDEO:
				current_state = State.PLAYING_VIDEO
		)
	else:
		_advance_timeline()

func _handle_player_click() -> void:
	match current_state:
		State.TYPING:
			if active_tween: active_tween.kill()
			story_label.visible_characters = story_label.get_parsed_text().length()
			current_state = State.SHOWING_TEXT
			
		State.SHOWING_TEXT:
			current_state = State.FADING_OUT_TEXT
			if active_tween: active_tween.kill()
			active_tween = create_tween()
			active_tween.tween_property(story_label, "modulate:a", 0.0, fade_speed)
			active_tween.finished.connect(_advance_timeline)
			
		State.FADING_OUT_TEXT:
			if active_tween: active_tween.kill()
			story_label.modulate.a = 0.0
			_advance_timeline()
			
		State.FADING_IN_IMAGE:
			if active_tween: active_tween.kill()
			story_image.modulate.a = 1.0
			current_state = State.SHOWING_IMAGE
			
		State.SHOWING_IMAGE:
			current_state = State.FADING_OUT_IMAGE
			if active_tween: active_tween.kill()
			active_tween = create_tween()
			active_tween.tween_property(story_image, "modulate:a", 0.0, fade_speed)
			active_tween.finished.connect(_advance_timeline)
			
		State.FADING_OUT_IMAGE:
			if active_tween: active_tween.kill()
			story_image.modulate.a = 0.0
			_advance_timeline()
			
		State.FADING_IN_VIDEO:
			if active_tween: active_tween.kill()
			story_video.modulate.a = 1.0
			current_state = State.PLAYING_VIDEO
			
		State.PLAYING_VIDEO:
			_fade_out_video()
			
		State.FADING_OUT_VIDEO:
			if active_tween: active_tween.kill()
			story_video.modulate.a = 0.0
			story_video.stop()
			_advance_timeline()

func _on_video_finished() -> void:
	if current_state == State.PLAYING_VIDEO:
		_fade_out_video()

func _fade_out_video() -> void:
	current_state = State.FADING_OUT_VIDEO
	if active_tween: active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(story_video, "modulate:a", 0.0, fade_speed)
	active_tween.finished.connect(func():
		story_video.stop()
		_advance_timeline()
	)

func _advance_timeline() -> void:
	if is_transitioning:
		return

	current_index += 1
	if current_index >= intro_slides.size():
		_transition_to_game()
	else:
		_load_current_step()

func _transition_to_game() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	set_process_input(false)
	
	if bgm_player and bgm_player.playing:
		var audio_tween = create_tween()
		# Fast fade audio on skip
		audio_tween.tween_property(bgm_player, "volume_db", -80.0, 0.3)
		audio_tween.finished.connect(func():
			bgm_player.stop()
			get_tree().change_scene_to_file(next_scene_path)
		)
	else:
		get_tree().change_scene_to_file(next_scene_path)
