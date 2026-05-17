extends Node
# ═════════════════════════════════════════════════════════════════════════════
#  GachaManager.gd  —  autoload singleton
#
#  Key improvements:
#   • Local collection cache  → zero read-before-write HTTP calls
#   • randi() % pool.size()   → pools never mutated by shuffle()
#   • Typed pulls return GachaResultData, not raw Dicts
#   • Full duplicate resolution: constellation / refinement / overflow
#   • Single reusable _http_* layer — HTTPRequest nodes always freed
#   • INSTANT SYNC: Updates GameManager memory on pull for real-time UI
# ═════════════════════════════════════════════════════════════════════════════

# ── Gacha rates ──────────────────────────────────────────────────────────────
const BASE_RATE_5STAR  := 0.020
const BASE_RATE_4STAR  := 0.130
const SOFT_PITY_START  := 65
const HARD_PITY_5STAR  := 80
const HARD_PITY_4STAR  := 10

# ── Duplicate caps ───────────────────────────────────────────────────────────
const MAX_CONSTELLATION := 6
const MAX_REFINEMENT    := 5
const SHARD_ON_C6_DUPE  := 5   ## Stella Fortuna shards given at C6 overflow
const PULLS_ON_R5_DUPE  := 1   ## Pull refund on R5 overflow

# ── Resource paths ───────────────────────────────────────────────────────────
const CHAR_POOL_PATH := "res://Resources/Characters/"
const CARD_POOL_PATH := "res://Resources/GachaCards/"

# ── Preload result type ───────────────────────────────────────────────────────
const GachaResultData := preload("res://Scripts/GachaResultData.gd")

# ── Pity state (synced to DB after every batch) ──────────────────────────────
var pity_count:          int  = 0
var pity_count_4star:    int  = 0
var guaranteed_featured: bool = false

# ── Local collection cache (loaded once on login, written-to on pull) ─────────
#    Avoids read-before-write on every duplicate check.
var _owned_characters: Dictionary = {}  ## { character_id(int): constellation(int) }
var _owned_cards:      Dictionary = {}  ## { card_item_id(int): stack_count(int)   }

# ── Immutable pull pools (never shuffled) ────────────────────────────────────
var _char_pool_5star: Array = []
var _char_pool_4star: Array = []
var _card_pool_5star: Array = []
var _card_pool_4star: Array = []
var _card_pool_3star: Array = []

signal pull_complete(results: Array)    ## Array[GachaResultData]

# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_build_pools()

# ═════════════════════════════════════════════════════════════════════════════
#  POOL BUILDER
# ═════════════════════════════════════════════════════════════════════════════
func _build_pools() -> void:
	_char_pool_5star.clear(); _char_pool_4star.clear()
	_card_pool_5star.clear(); _card_pool_4star.clear(); _card_pool_3star.clear()

	var dir := DirAccess.open(CHAR_POOL_PATH)
	if dir:
		for f in dir.get_files():
			if not f.ends_with(".tres"): continue
			var res := load(CHAR_POOL_PATH + f)
			if res is CharacterData:
				match res.star_rating:
					5: _char_pool_5star.append(res)
					4: _char_pool_4star.append(res)

	if DirAccess.dir_exists_absolute(CARD_POOL_PATH):
		var cdir := DirAccess.open(CARD_POOL_PATH)
		if cdir:
			for f in cdir.get_files():
				if not f.ends_with(".tres"): continue
				var res := load(CARD_POOL_PATH + f)
				if res is GachaCard:
					match res.star_rating:
						5: _card_pool_5star.append(res)
						4: _card_pool_4star.append(res)
						_: _card_pool_3star.append(res)

	print("GachaManager pools | 5★chr:%d  4★chr:%d  5★card:%d  4★card:%d  3★card:%d" % [
		_char_pool_5star.size(), _char_pool_4star.size(),
		_card_pool_5star.size(), _card_pool_4star.size(), _card_pool_3star.size()])

# ═════════════════════════════════════════════════════════════════════════════
#  INITIALISATION  (call once after login)
# ═════════════════════════════════════════════════════════════════════════════
func load_pity_from_profile() -> void:
	# Note the explicit : Dictionary typing here to prevent parser errors
	var p: Dictionary = GameManager.player_profile 
	
	pity_count          = int(p.get("pity_count", 0))
	pity_count_4star    = int(p.get("pity_count_4star", 0))
	guaranteed_featured = bool(p.get("guaranteed_featured", false))
	await _load_collection_cache()
	print("GachaManager ready | 5★pity:%d  4★pity:%d  guaranteed:%s" % [
		pity_count, pity_count_4star, guaranteed_featured])

func _load_collection_cache() -> void:
	var uid := int(GameManager.player_profile.get("uid", 0))
	if uid == 0: return

	# Characters
	var cr := await _http_get(
		"/rest/v1/player_characters?uid=eq.%d&select=character_id,constellation" % uid)
	if cr.ok:
		var arr = JSON.parse_string(cr.body)
		if arr is Array:
			for row in arr:
				_owned_characters[int(row.get("character_id", 0))] = int(row.get("constellation", 0))

	# Cards
	var ca := await _http_get(
		"/rest/v1/player_cards_owned?uid=eq.%d&select=card_item_id,stack_count" % uid)
	if ca.ok:
		var arr = JSON.parse_string(ca.body)
		if arr is Array:
			for row in arr:
				_owned_cards[int(row.get("card_item_id", 0))] = int(row.get("stack_count", 1))

	print("Collection cache loaded | chars:%d  cards:%d" % [
		_owned_characters.size(), _owned_cards.size()])

# ═════════════════════════════════════════════════════════════════════════════
#  PUBLIC PULL API
# ═════════════════════════════════════════════════════════════════════════════
func do_single_pull_typed() -> Array:
	return await _execute_pulls(1)

func do_ten_pull_typed() -> Array:
	return await _execute_pulls(10)

func do_single_pull() -> Array: return await do_single_pull_typed()
func do_ten_pull()   -> Array:  return await do_ten_pull_typed()

func can_pull(count: int) -> bool:
	return int(GameManager.player_profile.get("pulls", 0)) >= count

func deduct_pulls(count: int) -> void:
	var new_val := maxi(0, int(GameManager.player_profile.get("pulls", 0)) - count)
	GameManager.player_profile["pulls"] = new_val
	var uid := int(GameManager.player_profile.get("uid", 0))
	if uid == 0: return
	await _http_patch("/rest/v1/player_profile?uid=eq.%d" % uid, {"pulls": new_val})

# ═════════════════════════════════════════════════════════════════════════════
#  PULL EXECUTION
# ═════════════════════════════════════════════════════════════════════════════
func _execute_pulls(count: int) -> Array:
	var results: Array = []
	for _i in count:
		var raw  := _roll_rarity()
		var item := _pick_item(raw)
		var resolved: GachaResultData = await _resolve_duplicate(item)
		results.append(resolved)
	await _save_pity_to_db()
	pull_complete.emit(results)
	return results

# ─── Step 1: roll rarity ─────────────────────────────────────────────────────
func _roll_rarity() -> int:
	pity_count       += 1
	pity_count_4star += 1

	if pity_count       >= HARD_PITY_5STAR: return 5
	if pity_count_4star >= HARD_PITY_4STAR: return 4

	var rate5 := BASE_RATE_5STAR
	if pity_count >= SOFT_PITY_START:
		rate5 = minf(rate5 + 0.06 * float(pity_count - SOFT_PITY_START + 1), 1.0)

	var roll := randf()
	if roll < rate5:                   return 5
	if roll < rate5 + BASE_RATE_4STAR: return 4
	return 3

# ─── Step 2: pick item from pool (no pool mutation) ──────────────────────────
func _pick_item(rarity: int) -> Dictionary:
	match rarity:
		5: return _pick_5star()
		4: return _pick_4star()
		_: return _pick_3star()

func _pick_5star() -> Dictionary:
	pity_count       = 0
	pity_count_4star = 0

	var is_featured := guaranteed_featured or (randf() < 0.5)
	guaranteed_featured = not is_featured   # lost 50/50 → bank the guarantee

	if _char_pool_5star.is_empty():
		return _pick_5star_card()

	var char_data: CharacterData = \
		_char_pool_5star[0] if is_featured \
		else _char_pool_5star[randi() % _char_pool_5star.size()]

	return {"rarity": 5, "data": char_data, "is_featured": is_featured}

func _pick_5star_card() -> Dictionary:
	if _card_pool_5star.is_empty():
		return _pick_4star()
	return {
		"rarity":      5,
		"data":        _card_pool_5star[randi() % _card_pool_5star.size()],
		"is_featured": false,
	}

func _pick_4star() -> Dictionary:
	pity_count_4star = 0
	var pool: Array = []
	pool.append_array(_char_pool_4star)
	pool.append_array(_card_pool_4star)
	if pool.is_empty(): return _pick_3star()
	return {
		"rarity":      4,
		"data":        pool[randi() % pool.size()],
		"is_featured": false,
	}

func _pick_3star() -> Dictionary:
	return {
		"rarity":      3,
		"data":        _card_pool_3star[randi() % _card_pool_3star.size()] \
					   if not _card_pool_3star.is_empty() else null,
		"is_featured": false,
	}

# ═════════════════════════════════════════════════════════════════════════════
#  DUPLICATE RESOLUTION  (local cache → single DB write, no read)
# ═════════════════════════════════════════════════════════════════════════════
func _resolve_duplicate(raw: Dictionary) -> GachaResultData:
	var r          := GachaResultData.new()
	r.rarity       = raw.get("rarity", 3)
	r.data         = raw.get("data")
	r.is_featured  = raw.get("is_featured", false)

	if r.data is CharacterData:
		await _resolve_character(r)
	elif r.data is GachaCard:
		await _resolve_card(r)
	else:
		r.is_new = true

	return r

func _resolve_character(r: GachaResultData) -> void:
	var cid: int = r.data.character_id

	if cid not in _owned_characters:
		# ── Brand new ──────────────────────────────────────────────────────
		r.is_new              = true
		r.duplicate_outcome   = GachaResultData.DuplicateOutcome.NONE
		r.constellation_level = 0
		_owned_characters[cid] = 0
		await _db_insert_character(r.data)
	else:
		var c: int = _owned_characters[cid]
		if c < MAX_CONSTELLATION:
			# ── Constellation up ───────────────────────────────────────────
			c += 1
			_owned_characters[cid] = c
			r.duplicate_outcome    = GachaResultData.DuplicateOutcome.CONSTELLATION
			r.constellation_level  = c
			
			# INSTANT LOCAL SYNC: Update GameManager's constellation data
			if "player_characters" in GameManager:
				for char_dict in GameManager.player_characters:
					if char_dict.get("character_id") == cid:
						char_dict["constellation"] = c
						break
				if GameManager.has_signal("characters_updated"):
					GameManager.emit_signal("characters_updated")

			await _db_patch("/rest/v1/player_characters?uid=eq.%d&character_id=eq.%d" % [
				int(GameManager.player_profile.get("uid", 0)), cid],
				{"constellation": c})
		else:
			# ── C6 overflow → Stella Fortuna shards ────────────────────────
			r.duplicate_outcome   = GachaResultData.DuplicateOutcome.CONSTELLATION_MAX
			r.constellation_level = MAX_CONSTELLATION
			r.bonus_currency      = SHARD_ON_C6_DUPE
			await _add_currency("stella_shards", SHARD_ON_C6_DUPE)

func _resolve_card(r: GachaResultData) -> void:
	var cid: int = r.data.card_item_id

	if cid not in _owned_cards:
		r.is_new            = true
		r.duplicate_outcome = GachaResultData.DuplicateOutcome.NONE
		r.refinement_rank   = 1
		_owned_cards[cid]  = 1
		await _db_insert_card(r.data)
	else:
		var s: int = _owned_cards[cid]
		if s < MAX_REFINEMENT:
			s += 1
			_owned_cards[cid]   = s
			r.duplicate_outcome = GachaResultData.DuplicateOutcome.REFINEMENT
			r.refinement_rank   = s
			await _db_patch("/rest/v1/player_cards_owned?uid=eq.%d&card_item_id=eq.%d" % [
				int(GameManager.player_profile.get("uid", 0)), cid],
				{"stack_count": s})
		else:
			r.duplicate_outcome = GachaResultData.DuplicateOutcome.REFINEMENT_MAX
			r.refinement_rank   = MAX_REFINEMENT
			r.bonus_currency    = PULLS_ON_R5_DUPE
			await _add_currency("pulls", PULLS_ON_R5_DUPE)

# ═════════════════════════════════════════════════════════════════════════════
#  DB WRITE HELPERS
# ═════════════════════════════════════════════════════════════════════════════
func _db_insert_character(data: CharacterData) -> void:
	var uid := int(GameManager.player_profile.get("uid", 0))
	
	# 1. Prepare the exact data structure
	var new_char_data = {
		"uid":           uid,
		"character_id":  data.character_id,
		"current_level": 1,
		"current_exp":   0,
		"basic_level":   1,
		"skill_level":   1,
		"ult_level":     1,
		"talent_level":  1,
		"constellation": 0,
	}
	
	# 2. INSTANT LOCAL SYNC: Add to GameManager immediately
	if "player_characters" in GameManager:
		GameManager.player_characters.append(new_char_data.duplicate())
		if GameManager.has_signal("characters_updated"):
			GameManager.emit_signal("characters_updated")

	# 3. Send to Supabase
	await _http_post("/rest/v1/player_characters", new_char_data)

func _db_insert_card(data: GachaCard) -> void:
	var uid := int(GameManager.player_profile.get("uid", 0))
	await _http_post("/rest/v1/player_cards_owned", {
		"uid":          uid,
		"card_item_id": data.card_item_id,
		"stack_count":  1,
	})

func _save_pity_to_db() -> void:
	var uid := int(GameManager.player_profile.get("uid", 0))
	if uid == 0: return
	await _db_patch("/rest/v1/player_profile?uid=eq.%d" % uid, {
		"pity_count":          pity_count,
		"pity_count_4star":    pity_count_4star,
		"guaranteed_featured": guaranteed_featured,
	})
	GameManager.player_profile["pity_count"]          = pity_count
	GameManager.player_profile["pity_count_4star"]    = pity_count_4star
	GameManager.player_profile["guaranteed_featured"] = guaranteed_featured

func _add_currency(key: String, amount: int) -> void:
	var new_val := int(GameManager.player_profile.get(key, 0)) + amount
	GameManager.player_profile[key] = new_val
	var uid := int(GameManager.player_profile.get("uid", 0))
	if uid == 0: return
	await _db_patch("/rest/v1/player_profile?uid=eq.%d" % uid, {key: new_val})

func _db_patch(endpoint: String, payload: Dictionary) -> void:
	await _http_patch(endpoint, payload)

# ═════════════════════════════════════════════════════════════════════════════
#  HTTP UTILITY LAYER
# ═════════════════════════════════════════════════════════════════════════════
class HttpResult:
	var ok:   bool   = false
	var code: int    = 0
	var body: String = ""

func _make_headers(extra: Array = []) -> Array:
	var h := [
		"Content-Type: application/json",
		"apikey: "        + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token,
	]
	h.append_array(extra)
	return h

func _http_get(endpoint: String) -> HttpResult:
	return await _request(HTTPClient.METHOD_GET, endpoint, {})

func _http_post(endpoint: String, payload: Dictionary,
		extra_headers: Array = []) -> HttpResult:
	return await _request(HTTPClient.METHOD_POST, endpoint, payload, extra_headers)

func _http_patch(endpoint: String, payload: Dictionary) -> HttpResult:
	return await _request(HTTPClient.METHOD_PATCH, endpoint, payload)

func _request(method: int, endpoint: String, payload: Dictionary,
		extra_headers: Array = []) -> HttpResult:
	var result := HttpResult.new()
	var http   := HTTPRequest.new()
	SupabaseManager.add_child(http)

	var err := http.request(
		SupabaseManager.SUPABASE_URL + endpoint,
		_make_headers(extra_headers),
		method,
		"" if payload.is_empty() else JSON.stringify(payload)
	)

	if err != OK:
		push_error("GachaManager: request failed (err %d) → %s" % [err, endpoint])
		http.queue_free()
		return result

	var response        = await http.request_completed
	http.queue_free()

	result.code = response[1]
	result.body = response[3].get_string_from_utf8()
	result.ok   = result.code >= 200 and result.code < 300

	if not result.ok:
		push_error("GachaManager: HTTP %d from %s\n%s" % [result.code, endpoint, result.body])

	return result
