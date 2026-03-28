extends Node

var player_profile: Dictionary = {}
var player_characters: Array = []
var player_cards: Array = []

var in_combat: bool = false
var active_enemy = null
var active_enemy_data = null
var player_party: Array = []

func start_combat(enemy, enemy_data):
	if in_combat:
		return
	in_combat = true
	active_enemy = enemy
	active_enemy_data = enemy_data
	print("Combat started with: ", enemy_data)
	# Week 3: transition goes here

func end_combat():
	in_combat = false
	active_enemy = null
	active_enemy_data = null
