extends Resource
class_name EnemyData

# Basic Info
@export var enemy_id: int
@export var enemy_name: String
@export var english_name: String
@export var sprite: Texture2D

# Level
@export var current_level: int = 1
@export var max_level: int = 80

# Base Stats (at level 1)
@export var max_hp: int
@export var base_attack: int
@export var base_defense: int
@export var speed: int

# Stat scaling per level
@export var hp_per_level: float
@export var attack_per_level: float
@export var defense_per_level: float

# Elemental Shield
@export var shield_element: String
@export var shield_hp: int
@export var shield_hp_per_level: float  
@export var is_shield_active: bool

# rewards
@export var reward_cards: Array[Resource]
@export var reward_gold: int
@export var reward_exp: int               

# stats
func get_actual_hp() -> int:
	return int(max_hp + (hp_per_level * (current_level - 1)))

func get_actual_attack() -> int:
	return int(base_attack + (attack_per_level * (current_level - 1)))

func get_actual_defense() -> int:
	return int(base_defense + (defense_per_level * (current_level - 1)))

func get_actual_shield_hp() -> int:
	return int(shield_hp + (shield_hp_per_level * (current_level - 1)))
