extends Node2D

## EDIT THIS: path to whatever scene should load after the cutscene ends
const NEXT_SCENE := "res://Scenes/MainMenu.tscn"

## EDIT THIS: your panels — one entry per beat of the cutscene.
## "image" can be null if you don't have art yet; it'll just show black.
var panels := [
	{
		"image": null, # preload("res://Assets/Cutscene/panel_01.png"),
		"text": "Deng Kapampangan, mekeni la ring amanu da...",
	},
	{
		"image": null, # preload("res://Assets/Cutscene/panel_02.png"),
		"text": "At atsu ing salitang mengalub keng panaun...",
	},
]

@onready var bg: TextureRect = $CanvasLayer/Background
@onready var dialogue_label: RichTextLabel = $CanvasLayer/DialoguePanel/DialogueLabel
@onready var color_rect: ColorRect = $CanvasLayer/ColorRect
@onready var anim: AnimationPlayer = $CanvasLayer/AnimationPlayer

var current_panel := 0
var can_advance := false
var is_typing := false


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	show_panel(0)


func show_panel(index: int) -> void:
	can_advance = false
	var panel: Dictionary = panels[index]
	bg.texture = panel.get("image")
	dialogue_label.text = panel.get("text", "")
	dialogue_label.visible_ratio = 0.0
	anim.play("fade_in")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "fade_in":
		_type_text()


func _type_text() -> void:
	is_typing = true
	var tween := create_tween()
	var text_len := dialogue_label.get_total_character_count()
	var duration: float = clamp(text_len * 0.03, 0.5, 3.0)
	tween.tween_property(dialogue_label, "visible_ratio", 1.0, duration)
	tween.tween_callback(func():
		is_typing = false
		can_advance = true
	)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("ui_select") \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)

	if not pressed:
		return

	if is_typing:
		# Skip the typewriter effect, reveal full text instantly
		get_viewport().set_input_as_handled()
		dialogue_label.visible_ratio = 1.0
		is_typing = false
		can_advance = true
	elif can_advance:
		get_viewport().set_input_as_handled()
		advance()


func advance() -> void:
	current_panel += 1
	if current_panel >= panels.size():
		finish()
		return
	anim.play_backwards("fade_in") # fades to black between panels
	await anim.animation_finished
	show_panel(current_panel)


func finish() -> void:
	anim.play_backwards("fade_in")
	await anim.animation_finished
	get_tree().change_scene_to_file(NEXT_SCENE)
