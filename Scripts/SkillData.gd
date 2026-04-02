extends Resource
class_name SkillData

# ── Basic Info ─────────────────────────────────────────────────────────────────
@export var skill_id:          int
@export var skill_name:        String
@export var skill_description: String
@export var skill_icon:        Texture2D

# ── Type ──────────────────────────────────────────────────────────────────────
@export var skill_type: String   # "Basic" | "Skill" | "Ultimate" | "Talent"

# ── Skill Level ───────────────────────────────────────────────────────────────
@export var skill_level:              int   = 1
@export var max_skill_level:          int   = 10
@export var damage_bonus_per_level:   float = 0.06
@export var heal_bonus_per_level:     float = 0.04
@export var shield_bonus_per_level:   float = 0.0
@export var effect_bonus_per_level:   float = 0.02
@export var heal_flat_per_level:      int   = 50
@export var shield_flat_per_level:    int   = 0

# ── Cost & Generation ─────────────────────────────────────────────────────────
# Defaults to 0 so null-reads never crash
@export var sp_cost:    int = 0
@export var sp_gain:    int = 0
@export var energy_cost:int = 0
@export var energy_gain:int = 0

# ── Damage ────────────────────────────────────────────────────────────────────
@export var damage_multiplier: float = 0.0
@export var element:           String
@export var hits:              int   = 1

# ── Heal ──────────────────────────────────────────────────────────────────────
@export var heal_flat:       int   = 0
@export var heal_hp_scaling: float = 0.0

# ── Shield ────────────────────────────────────────────────────────────────────
@export var shield_flat:        int   = 0
@export var shield_def_scaling: float = 0.0

# ── Effect ────────────────────────────────────────────────────────────────────
@export var effect_type:     String
@export var effect_value:    float = 0.0
@export var effect_duration: int   = 0

# ── Target ────────────────────────────────────────────────────────────────────
@export var target_type: String   # "Single" | "AoE" | "Aoe" | "Team" | "Self"

# ── Talent Trigger ────────────────────────────────────────────────────────────
@export var trigger_card_category: String
@export var trigger_card_type:     String
@export var trigger_effect:        String
@export var trigger_value:         float = 0.0

# ── Calculators ───────────────────────────────────────────────────────────────
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

# ── Helpers ───────────────────────────────────────────────────────────────────
func is_damage_skill() -> bool:
	return effect_type == "Damage"

func targets_ally() -> bool:
	return effect_type in ["Heal", "Shield"] or \
		(effect_type == "Buff" and target_type in ["Single", "Self", "Team"])

func is_aoe() -> bool:
	return target_type in ["AoE", "Aoe", "Team"]
