extends CanvasLayer

@onready var ui_control = $Control
@onready var text_label = $Control/Panel/RichTextLabel
@onready var choice_container = get_node_or_null("Control/ChoiceContainer")

# --- Audio References ---
@onready var voice_player: AudioStreamPlayer = get_node_or_null("VoicePlayer")

# --- Logic States ---
var is_dialogue_active = false
var is_waiting_for_choice = false
var is_showing_feedback = false

# --- Camera References ---
var main_camera: Camera3D
var cinematic_camera: Camera3D

# --- Data Tracking ---
var current_lesson: NPCDialogue
var current_line_index = 0
var can_advance = false 

# --- Audio Replay Tracking ---
var current_voice_stream: AudioStream = null

func _ready():
	# Ensure BBCode is enabled so [color] tags work
	text_label.bbcode_enabled = true
	
	layer = 100
	ui_control.hide()
	if choice_container:
		choice_container.hide()
		
	# Setup Dialogue Box mouse filter so it detects clicks for voice replays
	var panel = $Control/Panel
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_dialogue_panel_gui_input)

func start_dialogue(npc: Node3D, player: Node3D, lesson: NPCDialogue):
	if is_dialogue_active: return
	
	current_lesson = lesson
	current_line_index = 0
	is_dialogue_active = true
	is_waiting_for_choice = false
	is_showing_feedback = false
	can_advance = false 
	
	update_ui_text()
	ui_control.show()
	
	# Safety timer to prevent instant skipping
	get_tree().create_timer(0.2).timeout.connect(func(): can_advance = true)
	
	if npc and player:
		setup_camera(npc, player)

func setup_camera(npc, player):
	main_camera = get_viewport().get_camera_3d()
	cinematic_camera = Camera3D.new()
	get_tree().root.add_child(cinematic_camera)
	
	var midpoint = (npc.global_position + player.global_position) / 2.0
	cinematic_camera.global_position = midpoint + Vector3(0, 2, 4)
	cinematic_camera.look_at(midpoint)
	cinematic_camera.make_current()

func update_ui_text():
	# Phase 1: NPC is talking through the lines in the Resource
	if current_line_index < current_lesson.npc_lines.size():
		text_label.text = current_lesson.npc_lines[current_line_index]
		
		# Clear old audio stream
		current_voice_stream = null
		
		# Check if your resource line points to a voice path string or an AudioStream object
		if current_lesson.get("voice_lines") and current_line_index < current_lesson.voice_lines.size():
			var voice_asset = current_lesson.voice_lines[current_line_index]
			if voice_asset is String and voice_asset != "":
				current_voice_stream = load(voice_asset)
			elif voice_asset is AudioStream:
				current_voice_stream = voice_asset
				
		# Play the audio track immediately for this line
		replay_voice()
	
	# Phase 2: NPC finished lines, now trigger the Quiz
	elif not is_waiting_for_choice and not is_showing_feedback:
		start_quiz()
	
	# Safety: If somehow called again, just close
	else:
		end_dialogue()

func start_quiz():
	is_waiting_for_choice = true
	
	# Load the custom quiz question voice track if it exists
	if current_lesson.get("quiz_voice"):
		current_voice_stream = current_lesson.quiz_voice
	else:
		current_voice_stream = null
	
	# Unlock the mouse so the player can click answers
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	text_label.text = current_lesson.quiz_question
	
	# Play quiz question voice instantly
	replay_voice()
	
	if choice_container:
		choice_container.show()
		# Clear any old buttons from previous lessons
		for child in choice_container.get_children(): 
			child.queue_free()
		
		var first_button = null
		
		# Create a button for each choice in the Resource
		for i in range(current_lesson.choices.size()):
			var btn = Button.new()
			btn.text = current_lesson.choices[i]
			btn.focus_mode = Control.FOCUS_ALL 
			btn.pressed.connect(_on_choice_selected.bind(i))
			choice_container.add_child(btn)
			
			if i == 0: 
				first_button = btn
		
		# Highlight the first button for keyboard/controller users
		if first_button:
			first_button.grab_focus.call_deferred()

func _on_choice_selected(index):
	is_waiting_for_choice = false 
	is_showing_feedback = true # This flag prevents the loop
	
	if choice_container: 
		choice_container.hide()
	
	# Apply Color, Show Message, and Load Feedback Voice
	if index == current_lesson.correct_index:
		text_label.text = "[color=green]" + current_lesson.success_msg + "[/color]"
		if current_lesson.get("success_voice"):
			current_voice_stream = current_lesson.success_voice
	else:
		text_label.text = "[color=red]" + current_lesson.fail_msg + "[/color]"
		if current_lesson.get("fail_voice"):
			current_voice_stream = current_lesson.fail_voice
			
	# Play the success or failure voice track instantly
	replay_voice()
	
	# Brief delay before they can press E to exit
	can_advance = false
	get_tree().create_timer(0.5).timeout.connect(func(): can_advance = true)

## Replays the voice file associated with the active dialogue sentence
func replay_voice():
	if voice_player and current_voice_stream:
		voice_player.stream = current_voice_stream
		voice_player.play()

## Detects clicks directly on the Dialogue box area to replay the sound
func _on_dialogue_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_dialogue_active and not is_waiting_for_choice and not is_showing_feedback:
			print("🔊 Dialogue block clicked! Replaying voice asset...")
			replay_voice()

func end_dialogue():
	is_dialogue_active = false
	is_waiting_for_choice = false
	is_showing_feedback = false
	current_voice_stream = null
	
	if voice_player and voice_player.is_playing():
		voice_player.stop()
	
	ui_control.hide()
	if choice_container: 
		choice_container.hide()
	
	# Put camera back
	if main_camera: 
		main_camera.make_current()
	if cinematic_camera: 
		cinematic_camera.queue_free()
	
	# Re-lock mouse to center for camera look controls
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Don't do anything if dialogue isn't running
	if not is_dialogue_active or not can_advance:
		return

	# If the user presses 'Interact' (E) or Clicks the mouse
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed):
		
		# 1. If we are currently showing a Quiz, DO NOT advance text
		if is_waiting_for_choice:
			return
			
		# 2. If we are showing the Feedback (Green/Red text), CLOSE the dialogue
		if is_showing_feedback:
			get_viewport().set_input_as_handled()
			end_dialogue()
			return

		# 3. Otherwise, just go to the next line of dialogue
		get_viewport().set_input_as_handled()
		current_line_index += 1
		update_ui_text()
