extends Node
# ─────────────────────────────────────────────
#  GachaManager — autoload singleton
#  Handles pull logic, pity, rates, DB sync
# ─────────────────────────────────────────────

# ── Rates ─────────────────────────────────────
const BASE_RATE_5STAR    = 0.020   # 2%
const BASE_RATE_4STAR    = 0.130   # 13% (top up to guarantee every 10)
const SOFT_PITY_START    = 65      # rate starts climbing here
const HARD_PITY_5STAR    = 80      # guaranteed 5-star
const HARD_PITY_4STAR    = 10      # guaranteed 4-star every 10

# ── Pool paths ────────────────────────────────
const CHAR_POOL_PATH     = "res://Resources/Characters/"
const CARD_POOL_PATH     = "res://Resources/GachaCards/"

# ── State (loaded from player_profile) ────────
var pity_count:           int  = 0
var pity_count_4star:     int  = 0
var guaranteed_featured:  bool = false

# ── Cached pools ──────────────────────────────
var _char_pool_5star: Array = []
var _char_pool_4star: Array = []
var _card_pool_3star: Array = []
var _card_pool_4star: Array = []
var _card_pool_5star: Array = []

signal pull_complete(results: Array)   # Array of pull result Dicts

func _ready():
	_build_pools()

# ─────────────────────────────────────────────
#  Pool builder
# ─────────────────────────────────────────────
func _build_pools():
	_char_pool_5star.clear()
	_char_pool_4star.clear()
	_card_pool_3star.clear()
	_card_pool_4star.clear()
	_card_pool_5star.clear()

	# Characters
	var dir = DirAccess.open(CHAR_POOL_PATH)
	if dir:
		for f in dir.get_files():
			if not f.ends_with(".tres"): continue
			var res = load(CHAR_POOL_PATH + f)
			if res is CharacterData:
				if res.star_rating == 5:
					_char_pool_5star.append(res)
				elif res.star_rating == 4:
					_char_pool_4star.append(res)

	# Gacha cards
	if DirAccess.dir_exists_absolute(CARD_POOL_PATH):
		var card_dir = DirAccess.open(CARD_POOL_PATH)
		if card_dir:
			for f in card_dir.get_files():
				if not f.ends_with(".tres"): continue
				var res = load(CARD_POOL_PATH + f)
				if res is GachaCard:
					match res.star_rating:
						5: _card_pool_5star.append(res)
						4: _card_pool_4star.append(res)
						_: _card_pool_3star.append(res)

	print("GachaManager pools — 5★ chars:", _char_pool_5star.size(),
		" 4★ chars:", _char_pool_4star.size(),
		" 5★ cards:", _card_pool_5star.size(),
		" 4★ cards:", _card_pool_4star.size(),
		" 3★ cards:", _card_pool_3star.size())

# ─────────────────────────────────────────────
#  Load pity from profile
# ─────────────────────────────────────────────
func load_pity_from_profile():
	var p = GameManager.player_profile
	pity_count          = int(p.get("pity_count", 0))
	pity_count_4star    = int(p.get("pity_count_4star", 0))
	guaranteed_featured = bool(p.get("guaranteed_featured", false))
	print("Pity loaded — 5★:", pity_count, " 4★:", pity_count_4star,
		" guaranteed:", guaranteed_featured)

# ─────────────────────────────────────────────
#  Pull entry points
# ─────────────────────────────────────────────
func do_single_pull() -> Array:
	return await _execute_pulls(1)

func do_ten_pull() -> Array:
	return await _execute_pulls(10)

func _execute_pulls(count: int) -> Array:
	var results: Array = []
	for i in range(count):
		results.append(await _single_pull())
	await _save_pity_to_db()
	emit_signal("pull_complete", results)
	return results

# ─────────────────────────────────────────────
#  Core single pull logic
# ─────────────────────────────────────────────
func _single_pull() -> Dictionary:
	pity_count        += 1
	pity_count_4star  += 1

	# ── Hard pity ──────────────────────────────
	if pity_count >= HARD_PITY_5STAR:
		return await _give_5star()

	if pity_count_4star >= HARD_PITY_4STAR:
		return await _give_4star()

	# ── Soft pity ──────────────────────────────
	var rate_5 = BASE_RATE_5STAR
	if pity_count >= SOFT_PITY_START:
		# +6% per pull after soft pity start
		rate_5 += 0.06 * (pity_count - SOFT_PITY_START + 1)
		rate_5  = min(rate_5, 1.0)

	var roll = randf()
	if roll < rate_5:
		return await _give_5star()
	elif roll < rate_5 + BASE_RATE_4STAR:
		return await _give_4star()
	else:
		return await _give_3star()

# ─────────────────────────────────────────────
#  Rarity resolvers
# ─────────────────────────────────────────────
func _give_5star() -> Dictionary:
	pity_count       = 0
	pity_count_4star = 0

	# 50/50 system
	var is_featured = guaranteed_featured or (randf() < 0.5)
	guaranteed_featured = not is_featured   # lost 50/50 → guarantee next

	# Pick character (50/50 between featured or random standard)
	var char_data: CharacterData = null
	if is_featured and _char_pool_5star.size() > 0:
		# Featured = first 5-star in pool (expand later per banner)
		char_data = _char_pool_5star[0]
	elif _char_pool_5star.size() > 0:
		_char_pool_5star.shuffle()
		char_data = _char_pool_5star[0]

	if char_data == null:
		# Fallback to 5-star card
		return await _give_5star_card()

	var success = await _add_character_to_db(char_data)
	if not success:
		print("ERROR: Failed to add 5-star character to database!")
	
	return {
		"type":      "character",
		"rarity":    5,
		"data":      char_data,
		"is_new":    true,
		"is_featured": is_featured,
		"success":   success
	}

func _give_5star_card() -> Dictionary:
	if _card_pool_5star.is_empty():
		return await _give_4star()
	
	_card_pool_5star.shuffle()
	var card: GachaCard = _card_pool_5star[0]
	var success = await _add_card_to_db(card)
	
	return {
		"type":   "card",
		"rarity": 5,
		"data":   card,
		"is_new": true,
		"success": success
	}

func _give_4star() -> Dictionary:
	pity_count_4star = 0

	# Mix of 4-star chars and 4-star cards
	var pool: Array = []
	pool.append_array(_char_pool_4star)
	pool.append_array(_card_pool_4star)

	if pool.is_empty():
		return await _give_3star()

	pool.shuffle()
	var item = pool[0]

	if item is CharacterData:
		var success = await _add_character_to_db(item)
		return {"type": "character", "rarity": 4, "data": item, "is_new": true, "success": success}
	else:
		var success = await _add_card_to_db(item)
		return {"type": "card", "rarity": 4, "data": item, "is_new": true, "success": success}

func _give_3star() -> Dictionary:
	if _card_pool_3star.is_empty():
		# Fallback — make a dummy result
		return {"type": "card", "rarity": 3, "data": null, "is_new": false, "success": false}

	_card_pool_3star.shuffle()
	var card: GachaCard = _card_pool_3star[0]
	var success = await _add_card_to_db(card)
	return {"type": "card", "rarity": 3, "data": card, "is_new": true, "success": success}

# ─────────────────────────────────────────────
#  Database writes - FIXED VERSIONS
# ─────────────────────────────────────────────
func _add_character_to_db(char_data: CharacterData) -> bool:
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0:
		print("ERROR: No UID found in player profile!")
		return false
	
	if char_data == null:
		print("ERROR: Character data is null!")
		return false
	
	print("Adding character to DB: ", char_data.character_name, " (ID: ", char_data.character_id, ") for UID: ", uid)
	
	var http = HTTPRequest.new()
	SupabaseManager.add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	
	var body = JSON.stringify({
		"uid":           int(uid),
		"character_id":  char_data.character_id,
		"current_level": 1,
		"current_exp":   0,
		"basic_level":   1,
		"skill_level":   1,
		"ult_level":     1,
		"talent_level":  1
	})
	
	# Use POST with ignore-duplicates to avoid errors if already owned
	var error = http.request(
		SupabaseManager.SUPABASE_URL + "/rest/v1/player_characters",
		headers + ["Prefer: resolution=ignore-duplicates"],
		HTTPClient.METHOD_POST, 
		body
	)
	
	if error != OK:
		print("ERROR: HTTP request failed to send!")
		http.queue_free()
		return false
	
	var response = await http.request_completed
	http.queue_free()
	
	var response_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	
	if response_code >= 200 and response_code < 300:
		print("SUCCESS: Character ", char_data.character_name, " added to DB!")
		return true
	else:
		print("ERROR: Failed to add character. Code: ", response_code, " Body: ", response_body)
		return false

func _add_card_to_db(card: GachaCard) -> bool:
	if card == null:
		print("ERROR: Card data is null!")
		return false
	
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0:
		print("ERROR: No UID found in player profile!")
		return false
	
	print("Adding card to DB: ", card.card_name, " (ID: ", card.card_item_id, ") for UID: ", uid)
	
	var http = HTTPRequest.new()
	SupabaseManager.add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	
	# First, check if the card is already owned
	var check_http = HTTPRequest.new()
	SupabaseManager.add_child(check_http)
	
	var check_url = SupabaseManager.SUPABASE_URL + "/rest/v1/player_cards_owned?uid=eq." + str(int(uid)) + "&card_item_id=eq." + str(card.card_item_id)
	var check_error = check_http.request(check_url, headers, HTTPClient.METHOD_GET, "")
	
	if check_error != OK:
		print("ERROR: Check request failed to send!")
		check_http.queue_free()
		http.queue_free()
		return false
	
	var check_response = await check_http.request_completed
	check_http.queue_free()
	
	var check_response_code = check_response[1]
	var check_body = check_response[3].get_string_from_utf8()
	
	if check_response_code >= 200 and check_response_code < 300:
		var existing = JSON.parse_string(check_body)
		
		if existing is Array and existing.size() > 0:
			# Card exists, increment stack count
			var current_stack = existing[0].get("stack_count", 1)
			var patch_http = HTTPRequest.new()
			SupabaseManager.add_child(patch_http)
			
			var patch_url = SupabaseManager.SUPABASE_URL + "/rest/v1/player_cards_owned?uid=eq." + str(int(uid)) + "&card_item_id=eq." + str(card.card_item_id)
			var patch_body = JSON.stringify({"stack_count": current_stack + 1})
			
			var patch_error = patch_http.request(patch_url, headers, HTTPClient.METHOD_PATCH, patch_body)
			
			if patch_error != OK:
				print("ERROR: Patch request failed to send!")
				patch_http.queue_free()
				http.queue_free()
				return false
			
			var patch_response = await patch_http.request_completed
			patch_http.queue_free()
			
			var patch_code = patch_response[1]
			if patch_code >= 200 and patch_code < 300:
				print("SUCCESS: Card stack incremented for ", card.card_name, " (now ", current_stack + 1, ")")
				return true
			else:
				print("ERROR: Failed to increment card stack. Code: ", patch_code)
				return false
		else:
			# New card, insert it
			var insert_body = JSON.stringify({
				"uid":          int(uid),
				"card_item_id": card.card_item_id,
				"stack_count":  1
			})
			
			var insert_error = http.request(
				SupabaseManager.SUPABASE_URL + "/rest/v1/player_cards_owned",
				headers,
				HTTPClient.METHOD_POST,
				insert_body
			)
			
			if insert_error != OK:
				print("ERROR: Insert request failed to send!")
				http.queue_free()
				return false
			
			var insert_response = await http.request_completed
			http.queue_free()
			
			var insert_code = insert_response[1]
			if insert_code >= 200 and insert_code < 300:
				print("SUCCESS: New card added to DB: ", card.card_name)
				return true
			else:
				var insert_body_text = insert_response[3].get_string_from_utf8()
				print("ERROR: Failed to add new card. Code: ", insert_code, " Body: ", insert_body_text)
				return false
	else:
		print("ERROR: Failed to check existing card. Code: ", check_response_code)
		http.queue_free()
		return false

func _save_pity_to_db():
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0:
		print("ERROR: Cannot save pity - no UID found!")
		return

	var http = HTTPRequest.new()
	SupabaseManager.add_child(http)
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	var body = JSON.stringify({
		"pity_count":          pity_count,
		"pity_count_4star":    pity_count_4star,
		"guaranteed_featured": guaranteed_featured
	})
	
	var error = http.request(
		SupabaseManager.SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)),
		headers, 
		HTTPClient.METHOD_PATCH, 
		body
	)
	
	if error != OK:
		print("ERROR: Failed to send pity save request!")
		http.queue_free()
		return
	
	var r = await http.request_completed
	http.queue_free()

	# Update local profile cache
	GameManager.player_profile["pity_count"]          = pity_count
	GameManager.player_profile["pity_count_4star"]    = pity_count_4star
	GameManager.player_profile["guaranteed_featured"] = guaranteed_featured
	print("Pity saved — 5★:", pity_count, " 4★:", pity_count_4star)

# ─────────────────────────────────────────────
#  Cost deduction helper (called from GachaScene)
# ─────────────────────────────────────────────
func can_pull(count: int) -> bool:
	return int(GameManager.player_profile.get("pulls", 0)) >= count

func deduct_pulls(count: int):
	var current = int(GameManager.player_profile.get("pulls", 0))
	var new_val  = max(0, current - count)
	GameManager.player_profile["pulls"] = new_val
	# Persist immediately
	_patch_pulls(new_val)

func _patch_pulls(new_val: int):
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0: return
	var http = HTTPRequest.new()
	SupabaseManager.add_child(http)
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SupabaseManager.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SupabaseManager.auth_token
	]
	http.request(
		SupabaseManager.SUPABASE_URL
		+ "/rest/v1/player_profile?uid=eq." + str(int(uid)),
		headers, HTTPClient.METHOD_PATCH,
		JSON.stringify({"pulls": new_val}))
	await http.request_completed
	http.queue_free()
