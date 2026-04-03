extends Resource
class_name GachaCard

# ── Identity ───────────────────────────────────────────────────────────────────
@export var card_item_id:   int
@export var card_name:      String
@export var card_name_kap:  String   # Kapampangan name
@export var description:    String
@export var card_art:       Texture2D
@export var star_rating:    int = 3  # 3 | 4 | 5

# ── Flat stat bonuses (all rarities) ──────────────────────────────────────────
@export var bonus_hp:      int   = 0
@export var bonus_atk:     int   = 0
@export var bonus_def:     int   = 0
@export var bonus_speed:   int   = 0

# ── Passive effect (5-star only) ──────────────────────────────────────────────
# trigger: "water_card_on_turn" | "fire_card_on_turn" | "none" etc.
@export var passive_trigger:     String = "none"
@export var passive_effect_type: String = "none"   # "dmg_bonus" | "heal_bonus" | "crit_rate" etc.
@export var passive_effect_value: float = 0.0

# ── Superimposition scaling (duplicate pulls) ──────────────────────────────────
# Each duplicate adds this % to the passive_effect_value and flat stats
@export var superimposition_bonus: float = 0.05  # +5% per stack

# ── Helpers ───────────────────────────────────────────────────────────────────
func get_scaled_passive(stack_count: int) -> float:
	if star_rating < 5: return 0.0
	return passive_effect_value + (superimposition_bonus * (stack_count - 1))

func get_scaled_atk(stack_count: int) -> int:
	return bonus_atk + int(bonus_atk * 0.1 * (stack_count - 1))

func get_scaled_hp(stack_count: int) -> int:
	return bonus_hp + int(bonus_hp * 0.1 * (stack_count - 1))

func get_color() -> Color:
	match star_rating:
		5: return Color(1.0, 0.75, 0.1)   # Gold
		4: return Color(0.7, 0.3, 1.0)    # Purple
		_: return Color(0.3, 0.6, 1.0)    # Blue
