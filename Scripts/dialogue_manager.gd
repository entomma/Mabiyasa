extends CanvasLayer

@onready var main_ui = $MainUI
@onready var text_label = $MainUI/DialogueBox/VBox/DialogueText
@onready var speaker_label = $MainUI/DialogueBox/VBox/SpeakerName
@onready var choice_container = $MainUI/ChoiceContainer
@onready var next_indicator = $MainUI/DialogueBox/NextIndicator
@onready var voice_player = $VoicePlayer

# --- Logic States ---
var is_dialogue_active = false
var is_waiting_for_choice = false
var is_showing_feedback = false

# --- Camera References ---
var main_camera: Camera3D
var cinematic_camera: Camera3D

# --- Data Tracking ---
var current_lesson # NPCDialogue Resource
var current_npc: Node3D
var current_line_index = 0
var can_advance = false 

# --- Animation Tracking ---
var current_voice_stream: AudioStream = null
var text_tween: Tween
var pulse_tween: Tween

func _ready():
	text_label.bbcode_enabled = true
	layer = 100
	main_ui.hide()
	choice_container.hide()
	next_indicator.hide()
	
	_start_pulse_animation()
	
	# Allow clicking the background to advance/skip
	main_ui.gui_input.connect(_on_main_ui_gui_input)

# ═══════════════════════════════════════════════════════
#  Dialogue Core
# ═══════════════════════════════════════════════════════

func start_dialogue(npc: Node3D, player: Node3D, lesson):
	if is_dialogue_active: return
	
	current_lesson = lesson
	current_npc = npc
	current_line_index = 0
	is_dialogue_active = true
	is_waiting_for_choice = false
	is_showing_feedback = false
	
	main_ui.show()
	choice_container.hide()
	
	# Lock mouse for UI interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_display_current_line()

func end_dialogue():
	is_dialogue_active = false
	is_waiting_for_choice = false
	is_showing_feedback = false
	current_voice_stream = null
	
	if voice_player and voice_player.is_playing():
		voice_player.stop()
	
	main_ui.hide()
	choice_container.hide()
	
	# Put camera back
	if main_camera: 
		main_camera.make_current()
	if cinematic_camera: 
		cinematic_camera.queue_free()
	
	# Re-lock mouse to center for camera look controls
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ═══════════════════════════════════════════════════════
#  Display & Animation
# ═══════════════════════════════════════════════════════

func _display_current_line():
	# If we have finished all normal dialogue lines...
	if current_line_index >= current_lesson.npc_lines.size():
		# Check if there is a quiz to trigger
		var has_quiz = current_lesson.get("quiz_question") != null and current_lesson.quiz_question != ""
		if has_quiz and not is_showing_feedback:
			_show_quiz_question()
			return
		else:
			# No quiz or quiz is done
			end_dialogue()
			return

	# Load the actual text from your resource
	var current_text = current_lesson.npc_lines[current_line_index]
	var speaker_name = current_npc.name if current_npc else "NPC"
	
	text_label.text = current_text
	speaker_label.text = speaker_name
	text_label.visible_ratio = 0.0
	
	next_indicator.hide()
	can_advance = false
	
	# Typewriter Effect
	if text_tween and text_tween.is_valid():
		text_tween.kill()
		
	text_tween = create_tween()
	var duration = current_text.length() * 0.03 
	text_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	text_tween.finished.connect(_on_text_finished)
	
	# Audio Voice Line handling
	if current_lesson.get("voice_lines") and current_line_index < current_lesson.voice_lines.size():
		var clip = current_lesson.voice_lines[current_line_index]
		if clip:
			current_voice_stream = clip
			voice_player.stream = current_voice_stream
			voice_player.play()
		else:
			current_voice_stream = null
			voice_player.stop()

func _on_text_finished():
	can_advance = true
	next_indicator.show()

func _start_pulse_animation():
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(next_indicator, "position:y", next_indicator.position.y + 5, 0.6).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(next_indicator, "position:y", next_indicator.position.y - 5, 0.6).set_trans(Tween.TRANS_SINE)

# ═══════════════════════════════════════════════════════
#  Quiz & Feedback Phase
# ═══════════════════════════════════════════════════════

func _show_quiz_question():
	speaker_label.text = "Quiz"
	text_label.text = current_lesson.quiz_question
	text_label.visible_ratio = 0.0
	
	# Play Quiz Audio if it exists
	if current_lesson.get("quiz_voice") != null:
		current_voice_stream = current_lesson.quiz_voice
		voice_player.stream = current_voice_stream
		voice_player.play()
	elif voice_player.is_playing():
		voice_player.stop()
		
	next_indicator.hide()
	can_advance = false
	
	if text_tween and text_tween.is_valid():
		text_tween.kill()
		
	text_tween = create_tween()
	var duration = text_label.text.length() * 0.03
	text_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	
	# Show choices when the question finishes typing
	text_tween.finished.connect(func():
		_show_choices(current_lesson.choices)
	)

func _show_feedback(is_correct: bool):
	is_showing_feedback = true
	is_waiting_for_choice = false
	
	speaker_label.text = "Result"
	var feedback_text = ""
	
	# Fetch the messages safely using 1 argument
	var s_msg = current_lesson.get("success_msg")
	var f_msg = current_lesson.get("fail_msg")
	
	# Handle Text and Voice based on Correct/Incorrect
	if is_correct:
		feedback_text = "[color=#5cdb5c]Correct![/color] " + (s_msg if s_msg != null else "")
		if current_lesson.get("success_voice") != null:
			current_voice_stream = current_lesson.success_voice
			voice_player.stream = current_voice_stream
			voice_player.play()
	else:
		feedback_text = "[color=#ff5c5c]Incorrect.[/color] " + (f_msg if f_msg != null else "")
		if current_lesson.get("fail_voice") != null:
			current_voice_stream = current_lesson.fail_voice
			voice_player.stream = current_voice_stream
			voice_player.play()
		
	text_label.text = feedback_text
	text_label.visible_ratio = 0.0
	
	next_indicator.hide()
	can_advance = false
	
	if text_tween and text_tween.is_valid():
		text_tween.kill()
		
	text_tween = create_tween()
	var duration = feedback_text.length() * 0.03
	text_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	text_tween.finished.connect(_on_text_finished)

# ═══════════════════════════════════════════════════════
#  Input Handling
# ═══════════════════════════════════════════════════════

func _on_main_ui_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_advance_or_skip()

func _input(event):
	if not is_dialogue_active: return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_try_advance_or_skip()

func _try_advance_or_skip():
	if is_waiting_for_choice:
		return # Do nothing, they must click a button to proceed
		
	if not can_advance:
		# Skip animation and show full text instantly.
		if text_tween and text_tween.is_valid():
			text_tween.kill()
		text_label.visible_ratio = 1.0
		
		# If we skipped during a quiz question, pop the choices immediately
		if current_line_index >= current_lesson.npc_lines.size() and not is_showing_feedback:
			_show_choices(current_lesson.choices)
		else:
			_on_text_finished()
	else:
		# Text is done, move to the next logical step
		if is_showing_feedback:
			end_dialogue()
		else:
			replay_voice()
			_advance_dialogue()

func _advance_dialogue():
	current_line_index += 1
	_display_current_line()

func replay_voice():
	if voice_player and current_voice_stream and not voice_player.is_playing():
		voice_player.play()

# ═══════════════════════════════════════════════════════
#  HSR Premium Choice Buttons
# ═══════════════════════════════════════════════════════

func _show_choices(choices: Array):
	is_waiting_for_choice = true
	can_advance = false
	next_indicator.hide()
	
	# Clear old choices
	for child in choice_container.get_children():
		child.queue_free()
		
	# Generate new choices
	for i in range(choices.size()):
		var btn = _create_choice_button(choices[i], i)
		choice_container.add_child(btn)
		
	choice_container.show()

func _create_choice_button(text: String, index: int) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(400, 56)
	
	# Base Style (Dark Glass)
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	sb_normal.border_width_left = 4
	sb_normal.border_color = Color(0.4, 0.45, 0.55, 1)
	sb_normal.corner_radius_top_right = 16
	sb_normal.corner_radius_bottom_right = 16
	sb_normal.content_margin_left = 24
	sb_normal.content_margin_top = 12
	sb_normal.content_margin_bottom = 12
	
	# Hover Style (Gold Highlight)
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.85, 0.75, 0.45, 1)
	sb_hover.border_color = Color(1, 1, 1, 1)
	
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1, 1))
	btn.add_theme_font_size_override("font_size", 18)
	
	btn.pressed.connect(_on_choice_selected.bind(index))
	return btn

func _on_choice_selected(index: int):
	is_waiting_for_choice = false
	choice_container.hide()
	
	# Cross-reference clicked button with correct index
	var correct_idx = current_lesson.get("correct_index")
	var is_correct = (index == correct_idx)
	
	_show_feedback(is_correct)
