class_name GachaResultData
extends RefCounted
# ─────────────────────────────────────────────────────────────────────────────
#  GachaResultData.gd
#  A clean, typed result object returned by GachaManager pulls.
#  Replaces raw Dictionary to prevent key-typo bugs and enable autocomplete.
# ─────────────────────────────────────────────────────────────────────────────

enum DuplicateOutcome {
	NONE,              ## First time obtaining
	CONSTELLATION,     ## Character dupe → gained constellation level
	CONSTELLATION_MAX, ## Character already C6 → converted to Stella Fortuna shards
	REFINEMENT,        ## Card/weapon dupe → gained refinement rank
	REFINEMENT_MAX,    ## Card already R5 → converted to gacha currency
}

# ── Core fields ───────────────────────────────────────────────────────────────
var rarity:           int             = 3
var data:             Resource        = null   ## CharacterData or GachaCard
var is_new:           bool            = false
var is_featured:      bool            = false

# ── Duplicate handling ─────────────────────────────────────────────────────────
var duplicate_outcome: DuplicateOutcome = DuplicateOutcome.NONE
var constellation_level: int         = 0     ## 0–6 after this pull
var refinement_rank:     int         = 1     ## 1–5 after this pull
var bonus_currency:      int         = 0     ## Shards / pulls given on overflow

# ── Convenience ───────────────────────────────────────────────────────────────
func get_display_name() -> String:
	if data is CharacterData: return data.character_name
	if data is GachaCard:     return data.card_name_kap
	return str(rarity) + "★ Item"

func get_sub_text() -> String:
	if data is CharacterData:
		var suffix := ""
		match duplicate_outcome:
			DuplicateOutcome.CONSTELLATION:
				suffix = "  ✦ C" + str(constellation_level)
			DuplicateOutcome.CONSTELLATION_MAX:
				suffix = "  ✦ C6 MAX  (+" + str(bonus_currency) + " Shards)"
		return data.job + " · " + data.element + suffix
	if data is GachaCard:
		var suffix := ""
		match duplicate_outcome:
			DuplicateOutcome.REFINEMENT:
				suffix = "  ✦ R" + str(refinement_rank)
			DuplicateOutcome.REFINEMENT_MAX:
				suffix = "  ✦ R5 MAX  (+" + str(bonus_currency) + " Pulls)"
		return data.card_name + " · " + str(rarity) + "★ Card" + suffix
	return ""

func get_art() -> Texture2D:
	if data is CharacterData and data.splash_art: return data.splash_art
	if data is GachaCard and data.card_art:       return data.card_art
	return null

func get_duplicate_badge_text() -> String:
	match duplicate_outcome:
		DuplicateOutcome.CONSTELLATION:
			return "C" + str(constellation_level)
		DuplicateOutcome.CONSTELLATION_MAX:
			return "C6 +" + str(bonus_currency) + "✦"
		DuplicateOutcome.REFINEMENT:
			return "R" + str(refinement_rank)
		DuplicateOutcome.REFINEMENT_MAX:
			return "R5 +" + str(bonus_currency) + "✦"
		_:
			return ""
