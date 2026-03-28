extends Control

# Element colors for placeholders
const ELEMENT_COLORS = {
	"Water": Color(0.2, 0.4, 0.9),
	"Wind": Color(0.2, 0.8, 0.4),
	"Fire": Color(0.9, 0.3, 0.1),
	"Earth": Color(0.6, 0.4, 0.2)
}

var all_characters: Array = []
var selected_party: Array = [null, null, null, null]
var active_slot: int = -1

@onready var slot_buttons = [
	$CharacterDisplay/Slot1/SlotButton1,
	$CharacterDisplay/Slot2/SlotButton2,
	$CharacterDisplay/Slot3/SlotButton3,
	$CharacterDisplay/Slot4/SlotButton4
]
@onready var slot_colors = [
	$CharacterDisplay/Slot1/SlotColor1,
	$CharacterDisplay/Slot2/SlotColor2,
	$CharacterDisplay/Slot3/SlotColor3,
	$CharacterDisplay/Slot4/SlotColor4
]
@onready var slot_infos = [
	$CharacterDisplay/Slot1/SlotInfo1,
	$CharacterDisplay/Slot2/SlotInfo2,
	$CharacterDisplay/Slot3/SlotInfo3,
	$CharacterDisplay/Slot4/SlotInfo4
]
@onready var available_list = $AvailablePanel/VBoxContainer/AvailableList
@onready var confirm_btn = $BottomBar/ConfirmButton
@onready var uid_label = $BottomBar/UIDLabel
@onready var back_btn = $TopBar/BackButton

func _ready():
	confirm_btn.pressed.connect(_on_confirm_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	for i in range(4):
		var idx = i
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(idx))
	
	uid_label.text = "UID: " + str(int(GameManager.player_profile.get("uid", 0)))
	
	# Hide all slot colors initially
	for color_rect in slot_colors:
		color_rect.visible = false
	
	load_characters()
	
	# Auto add Manasan to slot 0
	for char_data in all_characters:
		if char_data.character_id == 1:
			selected_party[0] = char_data
			break
	
	update_slots()

func load_characters():
	all_characters.clear()
	for db_char in GameManager.player_characters:
		var char_id = db_char.get("character_id", 0)
		var char_resource = GameManager.get_character_by_id(char_id)
		if char_resource:
			char_resource.current_level = db_char.get("current_level", 1)
			all_characters.append(char_resource)
	print("Available: ", all_characters.size(), " characters")
	populate_available_list()

func populate_available_list():
	for child in available_list.get_children():
		child.queue_free()
	
	for char_data in all_characters:
		var container = VBoxContainer.new()
		
		# Color rectangle preview
		var color_preview = ColorRect.new()
		color_preview.custom_minimum_size = Vector2(80, 80)
		color_preview.color = ELEMENT_COLORS.get(char_data.element, Color.GRAY)
		
		# Name label
		var name_label = Label.new()
		name_label.text = char_data.character_name + "\nLv." + str(char_data.current_level)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Click button overlay
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 110)
		btn.text = ""
		btn.pressed.connect(_on_available_char_pressed.bind(char_data))
		
		container.add_child(color_preview)
		container.add_child(name_label)
		container.add_child(btn)
		available_list.add_child(container)

func _on_slot_pressed(index: int):
	if index == 0:
		print("Manasan is always in slot 1!")
		return
	
	active_slot = index
	print("Slot " + str(index + 1) + " selected!")
	
	for i in range(4):
		if i == active_slot:
			slot_buttons[i].modulate = Color(1.5, 1.5, 0.5)
		else:
			slot_buttons[i].modulate = Color(1, 1, 1)

func _on_available_char_pressed(char_data: CharacterData):
	# Check if already in party — remove if so
	if selected_party.has(char_data):
		for i in range(1, 4):
			if selected_party[i] == char_data:
				selected_party[i] = null
				print(char_data.character_name + " removed!")
				break
	elif active_slot != -1 and active_slot != 0:
		selected_party[active_slot] = char_data
		active_slot = -1
		for btn in slot_buttons:
			btn.modulate = Color(1, 1, 1)
		print(char_data.character_name + " added!")
	else:
		# Auto fill first empty slot
		for i in range(1, 4):
			if selected_party[i] == null:
				selected_party[i] = char_data
				print(char_data.character_name + " added to slot " + str(i + 1))
				break
	
	update_slots()

func update_slots():
	for i in range(4):
		if selected_party[i] != null:
			var char_data = selected_party[i]
			# Show color rect hide button
			slot_buttons[i].visible = false
			slot_colors[i].visible = true
			slot_colors[i].color = ELEMENT_COLORS.get(char_data.element, Color.GRAY)
			slot_infos[i].text = char_data.character_name + "\n" + char_data.job
		else:
			# Show + button hide color rect
			slot_buttons[i].visible = true
			slot_colors[i].visible = false
			slot_infos[i].text = "Empty"
			slot_buttons[i].disabled = false

func _on_confirm_pressed():
	var party = []
	for char in selected_party:
		if char != null:
			party.append(char)
	
	if party.size() == 0:
		print("Select at least 1 character!")
		return
	
	GameManager.player_party = party
	print("Party confirmed: ", party.size(), " characters")
	get_tree().change_scene_to_file("res://Scenes/MainWorld.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainWorld.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
