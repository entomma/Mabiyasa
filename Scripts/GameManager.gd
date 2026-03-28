extends Node

var player_profile: Dictionary = {}
var player_characters: Array = []
var player_cards: Array = []

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

func end_combat():
	in_combat = false
	active_enemy = null
	active_enemy_data = null
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)
