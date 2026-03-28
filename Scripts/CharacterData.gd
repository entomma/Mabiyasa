extends Resource
class_name CharacterData

# Basic Info
@export var character_id: int
@export var character_name: String
@export var english_name: String
@export var job: String
@export var splash_art: Texture2D
@export var sprite: Texture2D

# Element
@export var element: String          # "Water", "Fire", "Earth", "Wind"

# Level
# Experience
@export var current_exp: int = 0
@export var current_level: int = 1
@export var max_level: int = 80

# Calculate EXP needed for next level dynamically
func get_exp_to_next_level() -> int:
	return int(100 * pow(current_level, 1.5))

# Base Stats (at level 1)
@export var max_hp: int
@export var base_attack: int
@export var base_defense: int
@export var speed: int

# Stat scaling per level (different per character role)
@export var hp_per_level: float
@export var attack_per_level: float
@export var defense_per_level: float

# Crit Stats
@export var crit_rate: float = 0.05
@export var crit_damage: float = .50

# Elemental
@export var elemental_bonus: float = 0.20

# Talent
@export var talent_name: String
@export var talent_description: String

# Skills
@export var basic_attack: Resource
@export var skill: Resource
@export var ultimate: Resource
@export var talent: Resource

# Cards
@export var signature_cards: Array[Resource]

# Stat calculators
func get_actual_hp() -> int:
	return int(max_hp + (hp_per_level * (current_level - 1)))

func get_actual_attack() -> int:
	return int(base_attack + (attack_per_level * (current_level - 1)))

func get_actual_defense() -> int:
	return int(base_defense + (defense_per_level * (current_level - 1)))
