extends Control

const ELEMENT_COLORS = {
	"Water": Color(0.2, 0.4, 0.9),
	"Wind": Color(0.2, 0.8, 0.4),
	"Fire": Color(0.9, 0.3, 0.1),
	"Earth": Color(0.6, 0.4, 0.2)
}

const MAX_LOADOUTS = 6

var all_characters: Array = []
var selected_party: Array = [null, null, null, null]
var active_slot: int = -1
var current_loadout: int = 1
var loadouts: Dictionary = {}

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

@onready var loadout_buttons = [
	$TopBar/TeamTabs/Tab1,
	$TopBar/TeamTabs/Tab2,
	$TopBar/TeamTabs/Tab3,
	$TopBar/TeamTabs/Tab4,
	$TopBar/TeamTabs/Tab5,
	$TopBar/TeamTabs/Tab6
]

func _ready():
	confirm_btn.pressed.connect(_on_confirm_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	
	for i in range(MAX_LOADOUTS):
		var btn = loadout_buttons[i]
		if btn:
			btn.pressed.connect(_on_loadout_pressed.bind(i + 1))
	
	for i in range(4):
		var idx = i
		var slot = get_slot_control(i)
		if slot:
			slot.gui_input.connect(_on_slot_clicked.bind(idx))
	
	uid_label.text = "UID: " + str(int(GameManager.player_profile.get("uid", 0)))
	
	for tex in slot_textures:
		tex.visible = false
	
	initialize_loadouts()
	load_characters()
	restore_party()
	update_slots()
	update_loadout_buttons()

func initialize_loadouts():
	var saved_loadouts = GameManager.player_profile.get("party_loadouts", {})
	loadouts = {}
	
	if saved_loadouts is Dictionary:
		# Postgres may return integer keys — normalize to strings
		for key in saved_loadouts:
			loadouts[str(key)] = saved_loadouts[key]
	
	for i in range(1, MAX_LOADOUTS + 1):
		var key = str(i)
		if not loadouts.has(key):
			loadouts[key] = [null, null, null, null]
		else:
			var existing = loadouts[key]
			if existing is Array:
				loadouts[key] = existing.duplicate()
			else:
				loadouts[key] = [null, null, null, null]
	
	current_loadout = GameManager.player_profile.get("current_loadout", 1)
	if typeof(current_loadout) != TYPE_INT:
		current_loadout = int(current_loadout)
	if current_loadout < 1 or current_loadout > MAX_LOADOUTS:
		current_loadout = 1

func _on_loadout_pressed(loadout_num: int):
	print("Switching from loadout ", current_loadout, " to ", loadout_num)
	
	# Save current to memory (store IDs only)
	save_to_loadout(current_loadout)
	
	# Switch to new loadout
	current_loadout = loadout_num
	
	# CRITICAL: Create fresh array for new loadout
	selected_party = [null, null, null, null]
	
	var loadout_key = str(current_loadout)
	if loadouts.has(loadout_key):
		var saved_ids = loadouts[loadout_key]
		print("Loading loadout ", loadout_num, " with IDs: ", saved_ids)
		
		for i in range(min(saved_ids.size(), 4)):
			var char_id = saved_ids[i]
			if char_id != null and char_id != 0:
				var c = get_char_from_list(int(char_id))
				if c:
					selected_party[i] = c
	
	# FIXED: Check if David (ID 1) is ALREADY in the party before adding default
	var david_already_present = false
	for i in range(4):
		if selected_party[i] != null and selected_party[i].character_id == 1:
			david_already_present = true
			break
	
	# Only add default Manasan if slot 0 is empty AND David isn't already in the party
	if selected_party[0] == null and not david_already_present:
		var manasan = get_char_from_list(1)
		if manasan:
			selected_party[0] = manasan
			print("Added default Manasan to slot 0")
	
	print("Loadout ", loadout_num, " loaded: ", selected_party)
	update_slots()
	update_loadout_buttons()
	
	# ─── AUTO-SAVE: Persist loadout switch to database ───
	save_loadout_to_database()

func save_to_loadout(loadout_num: int):
	# Store only ID numbers, NOT object references!
	var loadout_key = str(loadout_num)
	var party_ids = []
	for i in range(4):
		if selected_party[i] != null:
			party_ids.append(selected_party[i].character_id)
		else:
			party_ids.append(null)
	
	loadouts[loadout_key] = party_ids
	print("Saved loadout ", loadout_num, " with IDs: ", party_ids)

func save_loadout_to_database() -> void:
	"""Auto-save loadout state to Supabase immediately after modification"""
	var http = HTTPRequest.new()
	add_child(http)
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	var uid = GameManager.player_profile.get("uid", 0)
	var body = JSON.stringify({
		"party_loadouts": loadouts,
		"current_loadout": current_loadout
	})
	
	http.request_completed.connect(func(_result, _response_code, _headers, _body):
		http.queue_free()
		print("✓ Loadout auto-saved to database")
	)
	
	http.request(SupabaseManager.SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)

func update_loadout_buttons():
	for i in range(MAX_LOADOUTS):
		var btn = loadout_buttons[i]
		if not btn:
			continue
		
		var is_current = (i + 1 == current_loadout)
		var is_deployed = (i + 1 == GameManager.player_profile.get("current_loadout", 1))
		
		if is_current and is_deployed:
			btn.modulate = Color(0.8, 1.2, 0.8)
			btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
		elif is_current:
			btn.modulate = Color(1.3, 1.3, 0.5)
			btn.add_theme_color_override("font_color", Color.WHITE)
		elif is_deployed:
			btn.modulate = Color(1, 1, 1)
			btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		else:
			btn.modulate = Color(1, 1, 1)
			var loadout_key = str(i + 1)
			var has_chars = false
			if loadouts.has(loadout_key):
				for char_id in loadouts[loadout_key]:
					if char_id != null and char_id != 0:
						has_chars = true
						break
			if has_chars:
				btn.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
			else:
				btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func get_char_from_list(char_id: int) -> CharacterData:
	for c in all_characters:
		if c.character_id == char_id:
			return c.duplicate()
	return null

func restore_party():
	var loadout_key = str(current_loadout)
	var party_ids = []
	
	if loadouts.has(loadout_key):
		party_ids = loadouts[loadout_key]
	else:
		var legacy_party = GameManager.player_profile.get("saved_party", [])
		if legacy_party is Array:
			party_ids = legacy_party
		elif legacy_party is String:
			var cleaned = legacy_party.replace("{", "").replace("}", "").strip_edges()
			if cleaned != "":
				for id_str in cleaned.split(","):
					party_ids.append(int(float(id_str.strip_edges())))
	
	print("Restoring party from loadout ", current_loadout, " with IDs: ", party_ids)
	
	# CRITICAL: Always create fresh array
	selected_party = [null, null, null, null]
	
	if party_ids.size() > 0:
		var has_any = false
		for i in range(min(party_ids.size(), 4)):
			var char_id = party_ids[i]
			if char_id != null and char_id != 0:
				var c = get_char_from_list(int(char_id))
				if c:
					selected_party[i] = c
					has_any = true
		
		if has_any:
			# FIXED: Check if David is already present before adding default
			var david_present = false
			for i in range(4):
				if selected_party[i] != null and selected_party[i].character_id == 1:
					david_present = true
					break
			
			# Only add default if slot 0 is empty AND David isn't already there
			if selected_party[0] == null and not david_present:
				var manasan = get_char_from_list(1)
				if manasan:
					selected_party[0] = manasan
					print("Added default Manasan to slot 0 (restore_party)")
			return
	
	# Fallback - only if completely empty
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
		for i in range(4):
			var slot = get_slot_control(i)
			if slot:
				slot.modulate = Color(1.5, 1.5, 0.5) if i == active_slot else Color(1, 1, 1)

func _on_available_char_pressed(char_data: CharacterData):
	var found_at = -1
	for i in range(4):
		if selected_party[i] != null and selected_party[i].character_id == char_data.character_id:
			found_at = i
			break
	
	if active_slot != -1:
		if found_at != -1 and found_at == active_slot:
			# Remove from current slot
			selected_party[active_slot] = null
			print(char_data.character_name + " removed from slot " + str(active_slot + 1))
		elif found_at != -1 and found_at != active_slot:
			# SWAP: Use selected_party array only, NOT char_data!
			var temp = selected_party[active_slot]
			selected_party[active_slot] = selected_party[found_at]
			selected_party[found_at] = temp
			print(char_data.character_name + " swapped: now in slot " + str(active_slot + 1) + ", moved from slot " + str(found_at + 1))
		else:
			# Add new - create fresh duplicate
			selected_party[active_slot] = char_data.duplicate()
			print(char_data.character_name + " added to slot " + str(active_slot + 1))
	
	active_slot = -1
	char_select_panel.visible = false
	for i in range(4):
		var slot = get_slot_control(i)
		if slot:
			slot.modulate = Color(1, 1, 1)
	
	update_slots()
	update_loadout_buttons()
	save_to_loadout(current_loadout)
	GameManager.player_profile["party_loadouts"] = loadouts.duplicate()
	
	# ─── AUTO-SAVE: Persist character changes to database ───
	save_loadout_to_database()

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
	save_to_loadout(current_loadout)
	
	var party = []
	for c in selected_party:
		if c != null:
			party.append(c)
	
	if party.size() == 0:
		print("Select at least 1 character!")
		return
	
	GameManager.set_party(party)
	GameManager.player_profile["current_loadout"] = current_loadout
	
	var party_ids = []
	for c in selected_party:
		if c != null:
			party_ids.append(c.character_id)
		else:
			party_ids.append(0)
	
	var http = HTTPRequest.new()
	add_child(http)
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	var uid = GameManager.player_profile.get("uid", 0)
	var body = JSON.stringify({
		"party_loadouts": loadouts,
		"current_loadout": current_loadout,
		"saved_party": party_ids
	})
	
	http.request_completed.connect(func(_result, _response_code, _headers, _body):
		http.queue_free()
		print("Confirm save complete - deployed loadout ", current_loadout)
	)
	
	http.request(SupabaseManager.SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	
	GameManager.player_profile["party_loadouts"] = loadouts.duplicate()
	GameManager.player_profile["current_loadout"] = current_loadout
	GameManager.player_profile["saved_party"] = party_ids
	
	print("Deployed loadout ", current_loadout, " as active party")
	get_tree().change_scene_to_file("res://Scenes/HubTown.tscn")

func _on_close_pressed():
	print("Closed without deploying - no changes saved to DB")
	get_tree().change_scene_to_file("res://Scenes/HubTown.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if char_select_panel.visible:
			char_select_panel.visible = false
			active_slot = -1
		else:
			_on_close_pressed()
