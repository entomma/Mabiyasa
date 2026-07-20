extends Control

## Element styling configurations
const ELEMENT_COLORS: Dictionary = {
	"Water": Color(0.2, 0.4, 0.9),
	"Wind": Color(0.2, 0.8, 0.4),
	"Fire": Color(0.9, 0.3, 0.1),
	"Earth": Color(0.6, 0.4, 0.2)
}

const MAX_LOADOUTS: int = 6
const PARTY_SIZE: int = 4
const DEFAULT_CHARACTER_ID: int = 1 # ID for Manasan / Default character

# --- State Management ---
var all_characters: Array[CharacterData] = []
var selected_party: Array = [null, null, null, null] # Holds CharacterData or null
var active_slot: int = -1
var current_loadout: int = 1
var loadouts: Dictionary = {}

# --- Network Debouncing Nodes ---
var db_sync_timer: Timer
var db_http_request: HTTPRequest

# --- UI Nodes Bindings ---
@onready var slot_textures: Array[TextureRect] = [
	$CharacterDisplay/SlotsContainer/Slot1/SlotTexture1,
	$CharacterDisplay/SlotsContainer/Slot2/SlotTexture2,
	$CharacterDisplay/SlotsContainer/Slot3/SlotTexture3,
	$CharacterDisplay/SlotsContainer/Slot4/SlotTexture4
]
@onready var plus_icons: Array[Control] = [
	$CharacterDisplay/SlotsContainer/Slot1/PlusIcon1,
	$CharacterDisplay/SlotsContainer/Slot2/PlusIcon2,
	$CharacterDisplay/SlotsContainer/Slot3/PlusIcon3,
	$CharacterDisplay/SlotsContainer/Slot4/PlusIcon4
]
@onready var slot_names: Array[Label] = [
	$CharacterDisplay/SlotsContainer/Slot1/SlotInfo1/SlotName1,
	$CharacterDisplay/SlotsContainer/Slot2/SlotInfo2/SlotName2,
	$CharacterDisplay/SlotsContainer/Slot3/SlotInfo3/SlotName3,
	$CharacterDisplay/SlotsContainer/Slot4/SlotInfo4/SlotName4
]
@onready var slot_paths: Array[Label] = [
	$CharacterDisplay/SlotsContainer/Slot1/SlotInfo1/SlotPath1,
	$CharacterDisplay/SlotsContainer/Slot2/SlotInfo2/SlotPath2,
	$CharacterDisplay/SlotsContainer/Slot3/SlotInfo3/SlotPath3,
	$CharacterDisplay/SlotsContainer/Slot4/SlotInfo4/SlotPath4
]

# FIXED: Array strict-typing changed from Button to TextureButton
@onready var loadout_buttons: Array[TextureButton] = [
	$TopBar/TeamTabs/Tab1,
	$TopBar/TeamTabs/Tab2,
	$TopBar/TeamTabs/Tab3,
	$TopBar/TeamTabs/Tab4,
	$TopBar/TeamTabs/Tab5,
	$TopBar/TeamTabs/Tab6
]

@onready var available_list: BoxContainer = $CharacterSelectPanel/ScrollContainer/AvailableList
@onready var char_select_panel: Control = $CharacterSelectPanel

# FIXED: Strict-typing updated to TextureButton
@onready var confirm_btn: TextureButton = $BottomBar/ConfirmButton
@onready var uid_label: Label = $BottomBar/UIDLabel
@onready var close_btn: TextureButton = $TopBar/CloseButton

# --- Lifecycle Methods ---

func _ready() -> void:
	_setup_connections()
	_initialize_ui_state()
	_setup_network_nodes()
	
	# Live updates: listen to CharacterManager if the roster changes while this screen is loaded
	if CharacterManager.has_signal("characters_updated"):
		CharacterManager.characters_updated.connect(refresh_character_data)
		
	refresh_character_data()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if char_select_panel.visible:
			_close_character_select()
		else:
			_on_close_pressed()

# --- Initialization & Sync ---

func _setup_connections() -> void:
	confirm_btn.pressed.connect(_on_confirm_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	
	for i in range(MAX_LOADOUTS):
		if loadout_buttons[i]:
			loadout_buttons[i].pressed.connect(_on_loadout_pressed.bind(i + 1))
	
	for i in range(PARTY_SIZE):
		var slot = _get_slot_control(i)
		if slot:
			slot.gui_input.connect(_on_slot_clicked.bind(i))

func _initialize_ui_state() -> void:
	uid_label.text = "UID: %d" % AccountManager.uid
	for tex in slot_textures:
		tex.visible = false

## OPTIMIZATION: Configures shared asynchronous environment properties
func _setup_network_nodes() -> void:
	db_http_request = HTTPRequest.new()
	add_child(db_http_request)
	
	db_sync_timer = Timer.new()
	db_sync_timer.one_shot = true
	db_sync_timer.wait_time = 0.5  # Postpones syncing to database until 500ms after last tab shift
	db_sync_timer.timeout.connect(_execute_db_save)
	add_child(db_sync_timer)

## FIXES THE BUG: This pulls fresh data from the GameManager core anytime it runs
func refresh_character_data() -> void:
	initialize_loadouts()
	load_characters()
	restore_party()
	update_slots()
	update_loadout_buttons()

func load_characters() -> void:
	all_characters.clear()
	
	# Ensures we're reading the absolute latest roster state from CharacterManager
	for db_char in CharacterManager.player_characters:
		var char_id = db_char.get("character_id", 0)
		var char_resource = CharacterManager.get_character_by_id(char_id)
		if char_resource:
			var instance = char_resource.duplicate()
			instance.current_level = db_char.get("current_level", 1)
			all_characters.append(instance)
			
	populate_available_list()

func initialize_loadouts() -> void:
	loadouts.clear()
	for key in PartyManager.party_loadouts:
		loadouts[str(key)] = PartyManager.party_loadouts[key].duplicate()

	for i in range(1, MAX_LOADOUTS + 1):
		var key = str(i)
		if not loadouts.has(key) or not (loadouts[key] is Array):
			loadouts[key] = [null, null, null, null]

	current_loadout = clampi(PartyManager.current_loadout, 1, MAX_LOADOUTS)

# --- UI List Rendering (Genshin/HSR Pool Optimization) ---

## Professionally pools nodes to avoid garbage collection micro-stutter when opening the panel
func populate_available_list() -> void:
	var current_child_count = available_list.get_child_count()
	var target_count = all_characters.size()
	
	# Trim excess UI items instantly if roster shrank
	if current_child_count > target_count:
		for i in range(current_child_count - 1, target_count - 1, -1):
			available_list.get_child(i).queue_free()
			
	# Update existing or instantiate missing items
	for i in range(target_count):
		var char_data = all_characters[i]
		var card: VBoxContainer
		
		if i < current_child_count:
			card = available_list.get_child(i) as VBoxContainer
			_update_character_card(card, char_data)
		else:
			card = _create_character_card(char_data)
			available_list.add_child(card)

func _create_character_card(char_data: CharacterData) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(100, 130)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var texture_rect = TextureRect.new()
	texture_rect.name = "SplashArt"
	texture_rect.custom_minimum_size = Vector2(80, 80)
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.add_child(texture_rect)
	
	var name_lbl = Label.new()
	name_lbl.name = "CharName"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	container.add_child(name_lbl)
	
	var job_lbl = Label.new()
	job_lbl.name = "CharJob"
	job_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	job_lbl.add_theme_font_size_override("font_size", 10)
	container.add_child(job_lbl)
	
	var btn = Button.new()
	btn.name = "SelectButton"
	btn.text = "Add"
	btn.custom_minimum_size = Vector2(80, 25)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(btn)
	
	_update_character_card(container, char_data)
	return container

func _update_character_card(card: VBoxContainer, char_data: CharacterData) -> void:
	var texture_rect = card.get_node("SplashArt") as TextureRect
	var name_lbl = card.get_node("CharName") as Label
	var job_lbl = card.get_node("CharJob") as Label
	var btn = card.get_node("SelectButton") as Button
	
	# Handle dynamic visuals cleanly
	if char_data.splash_art:
		texture_rect.texture = char_data.splash_art
		texture_rect.modulate = Color.WHITE
	else:
		texture_rect.texture = null
		# Fallback design matching UI standards
		texture_rect.modulate = ELEMENT_COLORS.get(char_data.element, Color.GRAY)
		
	name_lbl.text = char_data.character_name
	job_lbl.text = char_data.job
	
	# Disconnect stale signals and bind the new dataset reference
	if btn.pressed.is_connected(_on_available_char_pressed):
		btn.pressed.disconnect(_on_available_char_pressed)
	btn.pressed.connect(_on_available_char_pressed.bind(char_data))

# --- Party Mechanics Logic ---

func _on_slot_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		active_slot = index
		char_select_panel.visible = true
		for i in range(PARTY_SIZE):
			var slot = _get_slot_control(i)
			if slot:
				slot.modulate = Color(1.5, 1.5, 0.5) if i == active_slot else Color.WHITE

func _on_available_char_pressed(char_data: CharacterData) -> void:
	if active_slot == -1: return
	
	var found_at: int = -1
	for i in range(PARTY_SIZE):
		if selected_party[i] != null and selected_party[i].character_id == char_data.character_id:
			found_at = i
			break
			
	if found_at != -1:
		if found_at == active_slot:
			selected_party[active_slot] = null
		else:
			# Premium hot-swap arrangement
			var temp = selected_party[active_slot]
			selected_party[active_slot] = selected_party[found_at]
			selected_party[found_at] = temp
	else:
		selected_party[active_slot] = char_data.duplicate()
		
	_close_character_select()
	update_slots()
	update_loadout_buttons()
	save_to_loadout(current_loadout)
	PartyManager.party_loadouts = loadouts.duplicate()
	
	save_loadout_to_database()

func _close_character_select() -> void:
	active_slot = -1
	char_select_panel.visible = false
	for i in range(PARTY_SIZE):
		var slot = _get_slot_control(i)
		if slot: slot.modulate = Color.WHITE

func update_slots() -> void:
	for i in range(PARTY_SIZE):
		var char_data = selected_party[i]
		if char_data != null:
			plus_icons[i].visible = false
			slot_textures[i].visible = char_data.splash_art != null
			slot_textures[i].texture = char_data.splash_art
			slot_names[i].text = char_data.character_name
			slot_paths[i].text = char_data.job
			
			var slot_ctrl = _get_slot_control(i)
			if slot_ctrl:
				slot_ctrl.modulate = Color.WHITE if char_data.splash_art else ELEMENT_COLORS.get(char_data.element, Color.GRAY)
		else:
			plus_icons[i].visible = true
			slot_textures[i].visible = false
			slot_names[i].text = ""
			slot_paths[i].text = ""
			var slot_ctrl = _get_slot_control(i)
			if slot_ctrl: slot_ctrl.modulate = Color.WHITE

# --- Loadout Routing ---

func _on_loadout_pressed(loadout_num: int) -> void:
	save_to_loadout(current_loadout)
	current_loadout = loadout_num
	selected_party = [null, null, null, null]
	
	var loadout_key = str(current_loadout)
	if loadouts.has(loadout_key):
		var saved_ids = loadouts[loadout_key]
		for i in range(min(saved_ids.size(), PARTY_SIZE)):
			var char_id = saved_ids[i]
			if char_id != null and char_id != 0:
				selected_party[i] = get_char_from_list(int(char_id))
				
	_ensure_default_character_presence()
	update_slots()
	update_loadout_buttons()
	save_loadout_to_database()

func restore_party() -> void:
	# PartyManager.apply_loadouts() always fills every loadout key on login,
	# so `loadouts` here is guaranteed populated — no legacy fallback needed.
	var loadout_key = str(current_loadout)
	var party_ids: Array = loadouts.get(loadout_key, [])
					
	selected_party = [null, null, null, null]
	
	if party_ids.size() > 0:
		for i in range(min(party_ids.size(), PARTY_SIZE)):
			var char_id = party_ids[i]
			if char_id != null and char_id != 0:
				selected_party[i] = get_char_from_list(int(char_id))
		_ensure_default_character_presence()
	else:
		selected_party[0] = get_char_from_list(DEFAULT_CHARACTER_ID)

func _ensure_default_character_presence() -> void:
	var is_present = false
	for i in range(PARTY_SIZE):
		if selected_party[i] != null and selected_party[i].character_id == DEFAULT_CHARACTER_ID:
			is_present = true
			break
	if selected_party[0] == null and not is_present:
		selected_party[0] = get_char_from_list(DEFAULT_CHARACTER_ID)

func save_to_loadout(loadout_num: int) -> void:
	var party_ids = []
	for i in range(PARTY_SIZE):
		party_ids.append(selected_party[i].character_id if selected_party[i] != null else null)
	loadouts[str(loadout_num)] = party_ids

# FIXED: Now fetches child labels dynamically before applying color overrides to bypass TextureButton deficiencies
func update_loadout_buttons() -> void:
	var active_profile_loadout = PartyManager.current_loadout
	for i in range(MAX_LOADOUTS):
		var btn = loadout_buttons[i]
		if not btn: continue
		
		# Centralized fix: Reset modulate to white (neutral/transparent overlay)
		# This stops the script from forcing green/yellow tints over your atlas textures.
		btn.modulate = Color.WHITE
		
		var num = i + 1
		var is_current = (num == current_loadout)
		var is_deployed = (num == active_profile_loadout)
		
		var label = btn.get_node_or_null("Label") as Label
		
		if is_current and is_deployed:
			if label: label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
		elif is_current:
			if label: label.add_theme_color_override("font_color", Color.WHITE)
		elif is_deployed:
			if label: label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			var has_chars = false
			if loadouts.has(str(num)):
				for id in loadouts[str(num)]:
					if id != null and id != 0:
						has_chars = true
						break
			if label:
				label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0) if has_chars else Color(0.5, 0.5, 0.5))
# --- Helpers & Data Communication ---

func get_char_from_list(char_id: int) -> CharacterData:
	for c in all_characters:
		if c.character_id == char_id:
			return c.duplicate()
	return null

func _get_slot_control(index: int) -> Control:
	return get_node_or_null("CharacterDisplay/SlotsContainer/Slot%d" % (index + 1))

# --- Database / Networking Persistence ---

# OPTIMIZATION: Implements network safety filters to eliminate out-of-order execution risk
func save_loadout_to_database() -> void:
	if db_sync_timer:
		db_sync_timer.start()

func _execute_db_save() -> void:
	if not db_http_request: return
	db_http_request.cancel_request() 
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	var uid = AccountManager.uid
	var body = JSON.stringify({
		"party_loadouts": loadouts,
		"current_loadout": current_loadout
	})
	
	db_http_request.request(SupabaseManager.SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)

func _on_confirm_pressed() -> void:
	save_to_loadout(current_loadout)
	
	var deployed_party = selected_party.filter(func(c): return c != null)
	if deployed_party.size() == 0:
		return
		
	PartyManager.set_party(deployed_party)
	PartyManager.current_loadout = current_loadout
	PartyManager.party_loadouts = loadouts.duplicate()
	GameManager.next_spawn = ""
	
	_execute_db_save()
	GameManager.pending_zone = GameManager.get_return_scene()
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_close_pressed() -> void:
	save_to_loadout(current_loadout)
	_execute_db_save()
	GameManager.next_spawn = ""
	GameManager.pending_zone = GameManager.get_return_scene()
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")
