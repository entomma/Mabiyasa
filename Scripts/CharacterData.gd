extends Resource
class_name CharacterData

# ── Basic Info ─────────────────────────────────────────────────────────────────
@export var character_id:   int
@export var character_name: String
@export var english_name:   String
@export var job:            String
@export var splash_art:     Texture2D
@export var sprite:         Texture2D

# ── Rarity ────────────────────────────────────────────────────────────────────
@export var star_rating: int = 4   # 4 or 5 — set per character .tres file

# ── Element ────────────────────────────────────────────────────────────────────
@export var element: String

# ── Level / EXP ───────────────────────────────────────────────────────────────
@export var current_exp:   int = 0
@export var current_level: int = 1
@export var max_level:     int = 80

func get_exp_to_next_level() -> int:
	return int(100 * pow(current_level, 1.5))

# ── Base Stats ─────────────────────────────────────────────────────────────────
@export var max_hp:       int
@export var base_attack:  int
@export var base_defense: int
@export var speed:        int

# ── Stat scaling per level ─────────────────────────────────────────────────────
@export var hp_per_level:      float
@export var attack_per_level:  float
@export var defense_per_level: float

# ── Crit ──────────────────────────────────────────────────────────────────────
@export var crit_rate:   float = 0.05
@export var crit_damage: float = 1.50

# ── Elemental ─────────────────────────────────────────────────────────────────
@export var elemental_bonus: float = 0.20

# ── Energy ────────────────────────────────────────────────────────────────────
@export var current_energy:    float = 0.0
@export var max_energy:        float = 100.0
@export var energy_regen_rate: float = 1.0

func gain_energy(base_amount: float, affected_by_rate: bool = true) -> void:
	var gain = base_amount * energy_regen_rate if affected_by_rate else base_amount
	current_energy = min(current_energy + gain, max_energy)

func consume_energy() -> void:
	current_energy = 0.0

func is_ult_ready() -> bool:
	return current_energy >= max_energy

# ── Equipped card (light cone) — set at runtime ───────────────────────────────
var equipped_card: GachaCard  = null
var equipped_card_stack: int  = 1

# ── Talent ────────────────────────────────────────────────────────────────────
@export var talent_name:        String
@export var talent_description: String

# ── Skills ────────────────────────────────────────────────────────────────────
@export var basic_attack: Resource
@export var skill:        Resource
@export var ultimate:     Resource
@export var talent:       Resource

# ── Cards ─────────────────────────────────────────────────────────────────────
@export var signature_cards: Array[Resource]

# ── Stat calculators (includes equipped card bonuses) ─────────────────────────
func get_actual_hp() -> int:
	var base = int(max_hp + (hp_per_level * (current_level - 1)))
	if equipped_card:
		base += equipped_card.get_scaled_hp(equipped_card_stack)
	return base

func get_actual_attack() -> int:
	var base = int(base_attack + (attack_per_level * (current_level - 1)))
	if equipped_card:
		base += equipped_card.get_scaled_atk(equipped_card_stack)
	return base

func get_actual_defense() -> int:
	return int(base_defense + (defense_per_level * (current_level - 1)))

# ── Card passive helpers ───────────────────────────────────────────────────────
func get_card_passive_value() -> float:
	if equipped_card == null: return 0.0
	return equipped_card.get_scaled_passive(equipped_card_stack)

func get_card_passive_trigger() -> String:
	if equipped_card == null: return "none"
	return equipped_card.passive_trigger

func get_card_passive_effect() -> String:
	if equipped_card == null: return "none"
	return equipped_card.passive_effect_type
