extends Resource
class_name GachaCard

# ── Identity ───────────────────────────────────────────────────────────────────
@export var card_item_id:   int
@export var card_name:      String
@export var card_name_kap:  String   # Kapampangan name
@export var description:    String
@export var card_art:       Texture2D
@export var star_rating:    int = 3  # 3 | 4 | 5
@export var card_type:      String = "Action"  # "Action" (Verb), "Noun", "Adjective"
@export var element:        String = "Physical"  # Element type for bonuses

# ── Flat stat bonuses (all rarities) ──────────────────────────────────────────
@export var bonus_hp:      int   = 0
@export var bonus_atk:     int   = 0
@export var bonus_def:     int   = 0
@export var bonus_speed:   int   = 0

# ── Category for talents ──────────────────────────────────────────────────────
@export var category:      String = "Standard"  # For talent triggers

# ── Passive effect (5-star only) ──────────────────────────────────────────────
@export var passive_trigger:     String = "none"
@export var passive_effect_type: String = "none"
@export var passive_effect_value: float = 0.0

# ── Superimposition scaling ──────────────────────────────────────────────────
@export var superimposition_bonus: float = 0.05

func get_scaled_passive(stack_count: int) -> float:
	if star_rating < 5: return 0.0
	return passive_effect_value + (superimposition_bonus * (stack_count - 1))

func get_scaled_atk(stack_count: int) -> int:
	return bonus_atk + int(bonus_atk * 0.1 * (stack_count - 1))

func get_scaled_hp(stack_count: int) -> int:
	return bonus_hp + int(bonus_hp * 0.1 * (stack_count - 1))

func get_color() -> Color:
	match star_rating:
		5: return Color(1.0, 0.75, 0.1)
		4: return Color(0.7, 0.3, 1.0)
		_: return Color(0.3, 0.6, 1.0)
