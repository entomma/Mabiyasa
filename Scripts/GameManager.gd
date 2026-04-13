extends Node

var next_spawn: String = "default" # Add this line
var player_profile: Dictionary = {}
var player_characters: Array = []
var player_cards: Array = []
var owned_character_resources: Array = []
var saved_party_slots: Array = [null, null, null, null]
var _saved_player_position: Vector3 = Vector3.ZERO
var saved_player_position: Vector3:
	get:
		return _saved_player_position
	set(value):
		_saved_player_position = value

var has_saved_position: bool = false
var in_combat: bool = false
var active_enemy = null
var active_enemy_data = null
var player_party: Array = []
var transition: Node = null

# ── Origin scene tracking ──────────────────────────────────────────────────────
# Stored before combat starts so Battle.gd knows where to return
var origin_scene: String = "res://Scenes/Zone1.tscn"

func _ready():
	var transition_scene = preload("res://Scenes/Transition.tscn")
	transition = transition_scene.instantiate()
	transition.add_to_group("transition")
	add_child(transition)

func start_combat(enemy, enemy_data):
	if in_combat:
		return
	in_combat = true
	active_enemy      = enemy
	active_enemy_data = enemy_data

	# Record the current scene so Battle.gd can return here
	var current = get_tree().current_scene
	if current and current.scene_file_path != "":
		origin_scene = current.scene_file_path
		set_meta("last_scene", origin_scene)
		print("Origin scene stored: ", origin_scene)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)

	transition.start_transition("res://Scenes/Battle.tscn")

func end_combat():
	in_combat         = false
	active_enemy      = null
	active_enemy_data = null
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)

func set_party(party: Array) -> void:
	player_party = party
	print("Party saved: ", player_party.size(), " characters")
	for char in player_party:
		print(" - ", char.character_name)

func set_saved_position(pos: Vector3) -> void:
	if pos != Vector3.ZERO:
		saved_player_position = pos
		has_saved_position    = true

func load_character_resources() -> void:
	owned_character_resources.clear()
	for db_char in player_characters:
		var char_id      = db_char.get("character_id", 0)
		var char_resource = get_character_by_id(char_id)
		if char_resource:
			char_resource.current_level = db_char.get("current_level", 1)
			char_resource.current_exp   = db_char.get("current_exp", 0)
			owned_character_resources.append(char_resource)
	print("Loaded character resources: ", owned_character_resources.size())

func get_character_by_id(id: int) -> CharacterData:
	var path = "res://Resources/Characters/"
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".tres"):
			var char_data = load(path + f)
			if char_data is CharacterData and char_data.character_id == id:
				return char_data.duplicate()
	return null
