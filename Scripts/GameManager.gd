extends Node

var player_profile: Dictionary = {}
var player_characters: Array = []
var player_cards: Array = []
var owned_character_resources: Array = []
var _saved_player_position: Vector3 = Vector3.ZERO
var saved_player_position: Vector3:
	get:
		return _saved_player_position
	set(value):
		print("Position being set to: ", value, " from: ", get_stack())
		_saved_player_position = value
var has_saved_position: bool = false
var in_combat: bool = false
var active_enemy = null
var active_enemy_data = null
var player_party: Array = []
var transition: Node = null

func _ready():
	var transition_scene = preload("res://Scenes/Transition.tscn")
	transition = transition_scene.instantiate()
	transition.add_to_group("transition")  # add this line
	add_child(transition)

func start_combat(enemy, enemy_data):
	if in_combat:
		return
	in_combat = true
	active_enemy = enemy
	active_enemy_data = enemy_data
	
	# Freeze player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
	
	# Start transition to battle
	transition.start_transition("res://Scenes/Battle.tscn")

# Make sure these persist
func set_party(party: Array) -> void:
	player_party = party
	print("Party saved to GameManager: ", player_party.size(), " characters")
	for char in player_party:
		print(" - ", char.character_name)

func end_combat():
	in_combat = false
	active_enemy = null
	active_enemy_data = null
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)
# Convert DB character records to CharacterData resources
func load_character_resources() -> void:
	owned_character_resources.clear()
	
	for db_char in player_characters:
		var char_id = db_char.get("character_id", 0)
		var char_resource = get_character_by_id(char_id)
		
		if char_resource:
			# Apply saved level from DB
			char_resource.current_level = db_char.get("current_level", 1)
			char_resource.current_exp = db_char.get("current_exp", 0)
			owned_character_resources.append(char_resource)
	
	print("Loaded character resources: ", owned_character_resources.size())

func get_character_by_id(id: int) -> CharacterData:
	var path = "res://Resources/Characters/"
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".tres"):
			var char_data = load(path + f)
			if char_data is CharacterData and char_data.character_id == id:
				return char_data
	return null
