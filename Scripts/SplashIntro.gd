extends Control

# --- CONFIGURATION ---
@export var splash_images: Array[String] = [
	"res://Assets/GODOTLOGO.png",
	"res://Assets/BSIT4A.png",
	"res://Assets/CP9.png"
]

# Update this path to point exactly to your game's login/authentication scene
@export var next_scene_path: String = "res://Scenes/AuthScreen.tscn"

@export var fade_duration: float = 0.6
@export var hold_duration: float = 3.0

# --- NODE REFERENCES ---
@onready var texture_rect: TextureRect = $TextureRect

# --- INTERNAL STATE ---
var current_index: int = 0
var active_tween: Tween = null
var _is_transitioning: bool = false

func _ready() -> void:
	# Ensure the texture slot starts completely transparent
	texture_rect.modulate.a = 0.0
	
	if splash_images.is_empty():
		_goto_next_scene()
		return
		
	_play_next_splash()

# ═══════════════════════════════════════════════════════
#  Keyboard Input (Admin Skip)
# ═══════════════════════════════════════════════════════
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("adminskip"):
		get_viewport().set_input_as_handled()
		_goto_next_scene()

# ═══════════════════════════════════════════════════════
#  Splash Sequence Logic
# ═══════════════════════════════════════════════════════
func _play_next_splash() -> void:
	if _is_transitioning:
		return

	# If we have run through all images, proceed to the main game layout
	if current_index >= splash_images.size():
		_goto_next_scene()
		return
		
	var path = splash_images[current_index]
	
	if ResourceLoader.exists(path):
		texture_rect.texture = load(path)
	else:
		# Safety fallback: skip file if misspelled or missing
		current_index += 1
		_play_next_splash()
		return
		
	# Build the sequential fade tween chain
	if active_tween: active_tween.kill()
	active_tween = create_tween()
	
	# 1. Fade the logo in
	active_tween.tween_property(texture_rect, "modulate:a", 1.0, fade_duration)
	# 2. Keep it on screen
	active_tween.tween_interval(hold_duration)
	# 3. Fade it out to black
	active_tween.tween_property(texture_rect, "modulate:a", 0.0, fade_duration)
	
	# Move to the next sequence item when finished
	active_tween.finished.connect(func():
		if not _is_transitioning:
			current_index += 1
			_play_next_splash()
	)

func _goto_next_scene() -> void:
	if _is_transitioning:
		return
		
	_is_transitioning = true
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	get_tree().change_scene_to_file(next_scene_path)
