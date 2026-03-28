extends Resource
class_name SkillData

# Basic Info
@export var skill_id: int
@export var skill_name: String
@export var skill_description: String
@export var skill_icon: Texture2D

# Type
@export var skill_type: String

# Skill Level
@export var skill_level: int = 1
@export var max_skill_level: int = 10
@export var damage_bonus_per_level: float = 0.06
@export var heal_bonus_per_level: float = 0.04
@export var shield_bonus_per_level: float = 0.0
@export var effect_bonus_per_level: float = 0.02
@export var heal_flat_per_level: int = 50
@export var shield_flat_per_level: int = 0
# Cost & Generation
@export var sp_cost: int
@export var sp_gain: int
@export var energy_cost: int
@export var energy_gain: int

# Damage
@export var damage_multiplier: float
@export var element: String
@export var hits: int

# Heal
@export var heal_flat: int
@export var heal_hp_scaling: float

# Shield
@export var shield_flat: int
@export var shield_def_scaling: float

# Effect
@export var effect_type: String
@export var effect_value: float
@export var effect_duration: int

# Target
@export var target_type: String

# Talent Trigger
@export var trigger_card_category: String
@export var trigger_card_type: String
@export var trigger_effect: String
@export var trigger_value: float

# Calculators
func get_actual_multiplier() -> float:
	return damage_multiplier + (damage_bonus_per_level * (skill_level - 1))

func get_actual_heal_flat() -> int:
	return heal_flat + (heal_flat_per_level * (skill_level - 1))

func get_actual_heal_scaling() -> float:
	return heal_hp_scaling + (heal_bonus_per_level * (skill_level - 1))
	
func get_actual_shield_flat() -> int:
	return shield_flat + (shield_flat_per_level * (skill_level - 1))

func get_actual_shield_scaling() -> float:
	return shield_def_scaling + (shield_bonus_per_level * (skill_level - 1))

func get_actual_effect_value() -> float:
	return effect_value + (effect_bonus_per_level * (skill_level - 1))
