extends Control

const ELEMENT_COLORS = {
	"Water": Color(0.2, 0.4, 0.9),
	"Wind": Color(0.2, 0.8, 0.4),
	"Fire": Color(0.9, 0.3, 0.1),
	"Earth": Color(0.6, 0.4, 0.2)
}

var all_characters: Array = []
var selected_party: Array = [null, null, null, null]
var active_slot: int = -1

@onready var slot_textures = [
	$CharacterDisplay/SlotsContainer/Slot1/SlotTexture1,
	$CharacterDisplay/SlotsContainer/Slot2/SlotTexture2,
	$CharacterDisplay/SlotsContainer/Slot3/SlotTexture3,
	$CharacterDisplay/SlotsContainer/Slot4/SlotTexture4
]
@onready var plus_icons = [
	$CharacterDisplay/SlotsContainer/Slot1/PlusIcon1,
	$CharacterDisplay/SlotsContainer/Slot2/PlusIcon2,
	$CharacterDisplay/SlotsContainer/Slot3/PlusIcon3,
	$CharacterDisplay/SlotsContainer/Slot4/PlusIcon4
]
@onready var slot_names = [
	$CharacterDisplay/SlotsContainer/Slot1/SlotInfo1/SlotName1,
	$CharacterDisplay/SlotsContainer/Slot2/SlotInfo2/SlotName2,
	$CharacterDisplay/SlotsContainer/Slot3/SlotInfo3/SlotName3,
	$CharacterDisplay/SlotsContainer/Slot4/SlotInfo4/SlotName4
]
@onready var slot_paths = [
	$CharacterDisplay/SlotsContainer/Slot1/SlotInfo1/SlotPath1,
	$CharacterDisplay/SlotsContainer/Slot2/SlotInfo2/SlotPath2,
	$CharacterDisplay/SlotsContainer/Slot3/SlotInfo3/SlotPath3,
	$CharacterDisplay/SlotsContainer/Slot4/SlotInfo4/SlotPath4
]
@onready var available_list = $CharacterSelectPanel/ScrollContainer/AvailableList
@onready var char_select_panel = $CharacterSelectPanel
@onready var confirm_btn = $BottomBar/ConfirmButton
@onready var uid_label = $BottomBar/UIDLabel
@onready var close_btn = $TopBar/CloseButton

func _ready():
	confirm_btn.pressed.connect(_on_confirm_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	
	for i in range(4):
		var idx = i
		var slot = get_slot_control(i)
		if slot:
			slot.gui_input.connect(_on_slot_clicked.bind(idx))
	
	uid_label.text = "UID: " + str(int(GameManager.player_profile.get("uid", 0)))
	
	for tex in slot_textures:
		tex.visible = false
	
	load_characters()
	restore_party()
	update_slots()

func get_char_from_list(char_id: int) -> CharacterData:
	for char in all_characters:
		if char.character_id == char_id:
			return char.duplicate()
	return null

func restore_party():
	var party_ids = GameManager.player_profile.get("saved_party", [])
	
	var ids_array = []
	if party_ids is Array:
		ids_array = party_ids
	elif party_ids is String:
		var cleaned = party_ids.replace("{", "").replace("}", "").strip_edges()
		if cleaned != "":
			for id_str in cleaned.split(","):
				ids_array.append(int(float(id_str.strip_edges())))
	
	print("Restoring party from IDs: ", ids_array)
	
	if ids_array.size() > 0:
		var has_any = false
		for i in range(min(ids_array.size(), 4)):
			var char_id = int(ids_array[i])
			if char_id != 0:
				var char = get_char_from_list(char_id)
				if char:
					selected_party[i] = char
					has_any = true
					print("Restored slot ", i, ": ", char.character_name)
		if has_any:
			return
	
	print("No saved party - adding Manasan as default")
	var manasan = get_char_from_list(1)
	if manasan:
		selected_party[0] = manasan

func get_slot_control(index: int) -> Control:
	match index:
		0: return $CharacterDisplay/SlotsContainer/Slot1
		1: return $CharacterDisplay/SlotsContainer/Slot2
		2: return $CharacterDisplay/SlotsContainer/Slot3
		3: return $CharacterDisplay/SlotsContainer/Slot4
	return null

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
		container.custom_minimum_size = Vector2(100, 130)
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		if char_data.splash_art:
			var tex_preview = TextureRect.new()
			tex_preview.custom_minimum_size = Vector2(80, 80)
			tex_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tex_preview.texture = char_data.splash_art
			tex_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			container.add_child(tex_preview)
		else:
			var color_preview = ColorRect.new()
			color_preview.custom_minimum_size = Vector2(80, 80)
			color_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			color_preview.color = ELEMENT_COLORS.get(char_data.element, Color.GRAY)
			container.add_child(color_preview)
		
		var name_lbl = Label.new()
		name_lbl.text = char_data.character_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		
		var job_lbl = Label.new()
		job_lbl.text = char_data.job
		job_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		job_lbl.add_theme_font_size_override("font_size", 10)
		
		var btn = Button.new()
		btn.text = "Add"
		btn.custom_minimum_size = Vector2(80, 25)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_available_char_pressed.bind(char_data))
		
		container.add_child(name_lbl)
		container.add_child(job_lbl)
		container.add_child(btn)
		available_list.add_child(container)

func _on_slot_clicked(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		active_slot = index
		char_select_panel.visible = true
		print("Slot clicked: ", index, " active_slot set to: ", active_slot)
		for i in range(4):
			var slot = get_slot_control(i)
			if slot:
				slot.modulate = Color(1.5, 1.5, 0.5) if i == active_slot else Color(1, 1, 1)

func _on_available_char_pressed(char_data: CharacterData):
	print("Active slot when adding: ", active_slot)
	
	var found_at = -1
	for i in range(4):
		if selected_party[i] != null and selected_party[i].character_id == char_data.character_id:
			found_at = i
			break
	
	if active_slot != -1:
		if found_at != -1 and found_at == active_slot:
			selected_party[active_slot] = null
			print(char_data.character_name + " removed from slot " + str(active_slot + 1))
		elif found_at != -1 and found_at != active_slot:
			var temp = selected_party[active_slot]
			selected_party[active_slot] = char_data
			selected_party[found_at] = temp
			print(char_data.character_name + " swapped to slot " + str(active_slot + 1))
		else:
			selected_party[active_slot] = char_data
			print(char_data.character_name + " added to slot " + str(active_slot + 1))
	
	active_slot = -1
	char_select_panel.visible = false
	for i in range(4):
		var slot = get_slot_control(i)
		if slot:
			slot.modulate = Color(1, 1, 1)
	
	update_slots()

func update_slots():
	for i in range(4):
		if selected_party[i] != null:
			var char_data = selected_party[i]
			plus_icons[i].visible = false
			slot_textures[i].visible = true
			if char_data.splash_art:
				slot_textures[i].texture = char_data.splash_art
			else:
				slot_textures[i].visible = false
				get_slot_control(i).modulate = ELEMENT_COLORS.get(char_data.element, Color.GRAY)
			slot_names[i].text = char_data.character_name
			slot_paths[i].text = char_data.job
		else:
			plus_icons[i].visible = true
			slot_textures[i].visible = false
			slot_names[i].text = ""
			slot_paths[i].text = ""
			get_slot_control(i).modulate = Color(1, 1, 1)

func _on_confirm_pressed():
	var party = []
	for char in selected_party:
		if char != null:
			party.append(char)
	
	if party.size() == 0:
		print("Select at least 1 character!")
		return
	
	GameManager.set_party(party)
	
	var party_ids = []
	for char in selected_party:
		if char != null:
			party_ids.append(char.character_id)
		else:
			party_ids.append(0)
	
	print("Saving party IDs with slots: ", party_ids)
	
	var http = HTTPRequest.new()
	add_child(http)
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	var uid = GameManager.player_profile.get("uid", 0)
	var body = JSON.stringify({"saved_party": party_ids})
	
	http.request(SupabaseManager.SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	var response = await http.request_completed
	http.queue_free()
	print("Save party response code: ", response[1])
	
	# CRITICAL FIX: Update local cache immediately after successful save
	GameManager.player_profile["saved_party"] = party_ids
	
	get_tree().change_scene_to_file("res://Scenes/HubTown.tscn")

func _on_close_pressed():
	get_tree().change_scene_to_file("res://Scenes/HubTown.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if char_select_panel.visible:
			char_select_panel.visible = false
			active_slot = -1
		else:
			_on_close_pressed()
