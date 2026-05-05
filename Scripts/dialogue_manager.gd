extends CanvasLayer

@onready var ui_control = $Control
@onready var text_label = $Control/Panel/RichTextLabel

var is_dialogue_active = false
var main_camera: Camera3D
var cinematic_camera: Camera3D

var dialogue_lines = []
var current_line_index = 0
var can_advance = false # New safety flag

func _ready():
	layer = 100
	ui_control.hide()

func start_dialogue(npc: Node3D, player: Node3D, text: String):
	if is_dialogue_active: return
	
	dialogue_lines = text.split("|")
	current_line_index = 0
	is_dialogue_active = true
	can_advance = false # Disable clicking for a split second
	
	update_ui_text()
	ui_control.show()
	
	# Start a tiny timer so the player's initial 'E' press doesn't close it
	get_tree().create_timer(0.2).timeout.connect(func(): can_advance = true)
	
	if npc and player:
		setup_camera(npc, player)
	
	print("[Dialogue] Started with text: ", text)

func setup_camera(npc, player):
	main_camera = get_viewport().get_camera_3d()
	cinematic_camera = Camera3D.new()
	get_tree().root.add_child(cinematic_camera)
	
	var midpoint = (npc.global_position + player.global_position) / 2.0
	cinematic_camera.global_position = midpoint + Vector3(0, 2, 4)
	cinematic_camera.look_at(midpoint)
	cinematic_camera.make_current()

func update_ui_text():
	if current_line_index < dialogue_lines.size():
		text_label.text = dialogue_lines[current_line_index]
	else:
		end_dialogue()

func end_dialogue():
	print("[Dialogue] Ended.")
	is_dialogue_active = false
	ui_control.hide()
	
	if main_camera:
		main_camera.make_current()
	
	if cinematic_camera:
		cinematic_camera.queue_free()

func _input(event):
	# Only allow advancing if dialogue is active AND the safety timer finished
	if is_dialogue_active and can_advance:
		if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed):
			get_viewport().set_input_as_handled()
			current_line_index += 1
			update_ui_text()
