# ─────────────────────────────────────────────────────────────────────────────
#  GachaManager_DuplicateHandling.gd
#  PASTE these methods / constants into your existing GachaManager.gd autoload.
#  They replace the raw-dictionary pull functions with typed GachaResultData.
# ─────────────────────────────────────────────────────────────────────────────
#
#  REQUIRED profile keys (add to your player_profile if missing):
#    "constellations"  : Dictionary  { character_id : int  }   # 0–6
#    "refinements"     : Dictionary  { card_id       : int  }   # 1–5
#    "stella_shards"   : int                                    # overflow currency
#    "owned_characters": Array[String]                          # character ids
#    "owned_cards"     : Array[String]                          # card ids
#
# ─────────────────────────────────────────────────────────────────────────────

# ── Constellation / Refinement caps ──────────────────────────────────────────
const MAX_CONSTELLATION  := 6
const MAX_REFINEMENT     := 5
const SHARD_ON_C6_DUPE   := 5    ## Stella Fortuna shards given when C6 duped
const PULLS_ON_R5_DUPE   := 1    ## Pulls refunded when R5 card duped

# ─────────────────────────────────────────────────────────────────────────────
#  PUBLIC: replacements for do_single_pull / do_ten_pull
#  Returns Array[GachaResultData] instead of Array[Dictionary]
# ─────────────────────────────────────────────────────────────────────────────
func do_single_pull_typed() -> Array:       # Array[GachaResultData]
	var raw = await do_single_pull()        # your existing pull logic
	return _process_results(raw)

func do_ten_pull_typed() -> Array:          # Array[GachaResultData]
	var raw = await do_ten_pull()
	return _process_results(raw)

# ─────────────────────────────────────────────────────────────────────────────
#  PRIVATE: convert raw dicts → GachaResultData with duplicate resolution
# ─────────────────────────────────────────────────────────────────────────────
func _process_results(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		out.append(_resolve_duplicate(item))
	# Persist changes once after the whole batch
	_save_collection()
	return out

func _resolve_duplicate(raw: Dictionary) -> GachaResultData:
	var r := GachaResultData.new()
	r.rarity      = raw.get("rarity", 3)
	r.data        = raw.get("data")
	r.is_featured = raw.get("is_featured", false)

	var profile := GameManager.player_profile

	if r.data is CharacterData:
		_resolve_character_duplicate(r, profile)
	elif r.data is GachaCard:
		_resolve_card_duplicate(r, profile)
	else:
		r.is_new = true   # generic item

	return r

# ── Character duplicate logic ─────────────────────────────────────────────────
func _resolve_character_duplicate(r: GachaResultData, profile: Dictionary):
	var owned: Array       = profile.get("owned_characters", [])
	var consts: Dictionary = profile.get("constellations", {})
	var char_id: String    = r.data.character_name   # use a proper id field if you have one

	if char_id not in owned:
		# Brand new character
		r.is_new = true
		r.duplicate_outcome = GachaResultData.DuplicateOutcome.NONE
		r.constellation_level = 0
		owned.append(char_id)
		consts[char_id] = 0
	else:
		var current_c: int = consts.get(char_id, 0)
		if current_c < MAX_CONSTELLATION:
			current_c += 1
			consts[char_id] = current_c
			r.duplicate_outcome    = GachaResultData.DuplicateOutcome.CONSTELLATION
			r.constellation_level  = current_c
		else:
			# Already C6 — give Stella Fortuna shards
			var shards: int = profile.get("stella_shards", 0) + SHARD_ON_C6_DUPE
			profile["stella_shards"] = shards
			r.duplicate_outcome = GachaResultData.DuplicateOutcome.CONSTELLATION_MAX
			r.constellation_level = MAX_CONSTELLATION
			r.bonus_currency    = SHARD_ON_C6_DUPE

	profile["owned_characters"] = owned
	profile["constellations"]   = consts

# ── Card / weapon duplicate logic ─────────────────────────────────────────────
func _resolve_card_duplicate(r: GachaResultData, profile: Dictionary):
	var owned: Array       = profile.get("owned_cards", [])
	var refs:  Dictionary  = profile.get("refinements", {})
	var card_id: String    = r.data.card_name   # use a proper id field if you have one

	if card_id not in owned:
		r.is_new = true
		r.duplicate_outcome = GachaResultData.DuplicateOutcome.NONE
		r.refinement_rank   = 1
		owned.append(card_id)
		refs[card_id] = 1
	else:
		var current_r: int = refs.get(card_id, 1)
		if current_r < MAX_REFINEMENT:
			current_r += 1
			refs[card_id] = current_r
			r.duplicate_outcome = GachaResultData.DuplicateOutcome.REFINEMENT
			r.refinement_rank   = current_r
		else:
			# Already R5 — refund 1 pull
			var pulls: int = profile.get("pulls", 0) + PULLS_ON_R5_DUPE
			profile["pulls"]     = pulls
			r.duplicate_outcome  = GachaResultData.DuplicateOutcome.REFINEMENT_MAX
			r.refinement_rank    = MAX_REFINEMENT
			r.bonus_currency     = PULLS_ON_R5_DUPE

	profile["owned_cards"] = owned
	profile["refinements"] = refs

# ─────────────────────────────────────────────────────────────────────────────
#  Persist
# ─────────────────────────────────────────────────────────────────────────────
func _save_collection():
	# Call your existing save method — adjust to your implementation
	if GameManager.has_method("save_player_profile"):
		GameManager.save_player_profile()
