extends Node

const SUPABASE_URL = "http://127.0.0.1:54321"
const SUPABASE_ANON_KEY = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

var auth_token: String = ""
var current_uid: int = 0
var current_user_id: String = ""

func _ready():
	pass

# Register new account
func register(email: String, username: String, password: String) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY
	]
	
	var body = JSON.stringify({
		"email": email,
		"password": password
	})
	
	http.request(SUPABASE_URL + "/auth/v1/signup", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	http.queue_free()
	
	var result = JSON.parse_string(response[3].get_string_from_utf8())
	print("Register response: ", result)
	
	if result.has("access_token"):
		auth_token = result.access_token
		current_user_id = result.user.id
		
		# Create player profile after successful registration
		var profile_result = await create_player_profile(username)
		print("Profile creation result: ", profile_result)
		
		# Give starter characters
		await give_starter_characters()
	
	return result

# Login
func login(email: String, password: String) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY
	]
	
	var body = JSON.stringify({
		"email": email,
		"password": password
	})
	
	http.request(SUPABASE_URL + "/auth/v1/token?grant_type=password", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	http.queue_free()
	
	var result = JSON.parse_string(response[3].get_string_from_utf8())
	print("Login response: ", result)
	
	if result.has("access_token"):
		auth_token = result.access_token
		current_user_id = result.user.id
		await fetch_player_profile()
		print("Profile after fetch: ", GameManager.player_profile)
	
	return result

# Create player profile after register (working old version)
func create_player_profile(username: String) -> Variant:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token,
		"Prefer: return=representation"
	]
	
	var body = JSON.stringify({
		"account_id": current_user_id,
		"username": username,
		"party_loadouts": {
			"1": [1, null, null, null],
			"2": [1, null, null, null],
			"3": [1, null, null, null],
			"4": [1, null, null, null],
			"5": [1, null, null, null],
			"6": [1, null, null, null]
		},
		"current_loadout": 1,
		"saved_party": [1]
	})
	
	print("Creating profile...")
	print("Token: ", auth_token)
	print("User ID: ", current_user_id)
	
	http.request(SUPABASE_URL + "/rest/v1/player_profile", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	http.queue_free()
	
	var response_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	
	print("Response code: ", response_code)
	print("Response body: ", response_body)
	
	if response_body == "":
		return {"success": true}
	
	var result = JSON.parse_string(response_body)
	if result == null:
		return {"success": true}
	
	return result

# Give starter characters after profile creation
func give_starter_characters() -> void:
	# Wait a moment for profile to be created
	await get_tree().create_timer(1.0).timeout
	
	# Fetch profile to get UID
	await fetch_player_profile()
	
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0:
		print("No UID found!")
		return
	
	print("Giving starter characters to UID: ", uid)
	
	# Give Manasan character
	var http = HTTPRequest.new()
	add_child(http)
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	var body = JSON.stringify({
		"uid": int(uid),
		"character_id": 1,
		"current_level": 1,
		"current_exp": 0
	})
	http.request(SUPABASE_URL + "/rest/v1/player_characters", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	http.queue_free()
	print("Manasan given: ", response[3].get_string_from_utf8())
	
	# Reload characters
	await fetch_player_characters()
	
	# Load player state
	load_player_state()

# Fetch player profile
func fetch_player_profile() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	http.request(SUPABASE_URL + "/rest/v1/player_profile?account_id=eq." + current_user_id, headers, HTTPClient.METHOD_GET, "")
	var response = await http.request_completed
	http.queue_free()
	
	var response_body = response[3].get_string_from_utf8()
	print("Fetch profile response: ", response_body)
	
	var result = JSON.parse_string(response_body)
	if result != null and result.size() > 0:
		current_uid = result[0].uid
		GameManager.player_profile = result[0]
		print("Profile saved to GameManager: ", GameManager.player_profile)
	else:
		print("No profile found for user: ", current_user_id)

func fetch_player_characters() -> Array:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var uid = GameManager.player_profile.get("uid", 0)
	http.request(SUPABASE_URL + "/rest/v1/player_characters?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_GET, "")
	var response = await http.request_completed
	http.queue_free()
	
	var result = JSON.parse_string(response[3].get_string_from_utf8())
	print("Player characters from DB: ", result)
	
	if result != null and result is Array:
		GameManager.player_characters = result
		return result
	return []

func load_player_state() -> void:
	var profile = GameManager.player_profile
	
	# Restore position
	var pos_x = float(profile.get("last_pos_x", 0.0))
	var pos_y = float(profile.get("last_pos_y", 0.0))
	var pos_z = float(profile.get("last_pos_z", 0.0))
	var pos = Vector3(pos_x, pos_y, pos_z)
	
	if pos != Vector3.ZERO:
		GameManager.saved_player_position = pos
		GameManager.has_saved_position = true
		print("Position loaded: ", pos)
	
	# Load party from current loadout
	var current_loadout_raw = profile.get("current_loadout", 1)
	
	var current_loadout = 1
	if typeof(current_loadout_raw) == TYPE_FLOAT:
		current_loadout = int(current_loadout_raw)
	elif typeof(current_loadout_raw) == TYPE_INT:
		current_loadout = current_loadout_raw
	elif typeof(current_loadout_raw) == TYPE_STRING:
		current_loadout = int(current_loadout_raw)
	
	var party_loadouts = profile.get("party_loadouts", {})
	var party_ids = []
	
	if party_loadouts is Dictionary:
		var loadout_key = str(current_loadout)
		if party_loadouts.has(loadout_key):
			var loadout_data = party_loadouts[loadout_key]
			if loadout_data is Array:
				party_ids = loadout_data
				print("Loading party from current loadout ", current_loadout, ": ", party_ids)
	
	print("Parsed party IDs: ", party_ids)
	
	if party_ids.size() > 0:
		var party = []
		var slot_party = [null, null, null, null]
		
		for i in range(min(party_ids.size(), 4)):
			var char_id = party_ids[i]
			if char_id != null and char_id != 0:
				if typeof(char_id) == TYPE_FLOAT:
					char_id = int(char_id)
				elif typeof(char_id) == TYPE_STRING:
					char_id = int(char_id)
				
				var char_resource = GameManager.get_character_by_id(char_id)
				if char_resource:
					slot_party[i] = char_resource
					party.append(char_resource)
					print("Loaded slot ", i, ": ", char_resource.character_name)
		
		if party.size() > 0:
			GameManager.player_party = party
			GameManager.saved_party_slots = slot_party
			print("Party loaded: ", party.size(), " characters")
	else:
		print("No party found in current loadout ", current_loadout)

# Give Tanud after tutorial
func give_tanud() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var uid = GameManager.player_profile.get("uid", 0)
	var body = JSON.stringify({
		"uid": int(uid),
		"character_id": 6,
		"current_level": 1,
		"current_exp": 0
	})
	
	http.request(SUPABASE_URL + "/rest/v1/player_characters", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	http.queue_free()
	print("Tanud given: ", response[3].get_string_from_utf8())

# Save pull currency (pulls)
func spend_pulls(amount: int) -> bool:
	var current_pulls = GameManager.player_profile.get("pulls", 0)
	if current_pulls < amount:
		print("Not enough pulls!")
		return false
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var uid = GameManager.player_profile.get("uid", 0)
	var body = JSON.stringify({
		"pulls": current_pulls - amount
	})
	
	http.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	var _response = await http.request_completed
	http.queue_free()
	
	GameManager.player_profile["pulls"] = current_pulls - amount
	return true

func save_checkpoint(checkpoint_id: String, scene_name: String, pos: Vector3) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var uid = GameManager.player_profile.get("uid", 0)
	var body = JSON.stringify({
		"last_checkpoint": checkpoint_id,
		"current_scene": scene_name,
		"last_pos_x": pos.x,
		"last_pos_y": pos.y,
		"last_pos_z": pos.z
	})
	
	http.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	var response = await http.request_completed
	http.queue_free()
	
	GameManager.player_profile["last_checkpoint"] = checkpoint_id
	GameManager.player_profile["current_scene"] = scene_name
	GameManager.player_profile["last_pos_x"] = pos.x
	GameManager.player_profile["last_pos_y"] = pos.y
	GameManager.player_profile["last_pos_z"] = pos.z
	print("Checkpoint saved: ", checkpoint_id, " in ", scene_name)

# Add pulls after battle win
func add_pulls(amount: int) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var current_pulls = GameManager.player_profile.get("pulls", 0)
	var uid = GameManager.player_profile.get("uid", 0)
	var body = JSON.stringify({
		"pulls": current_pulls + amount
	})
	
	http.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	var response = await http.request_completed
	http.queue_free()
	
	GameManager.player_profile["pulls"] = current_pulls + amount
	print("Pulls added: ", amount, " Total: ", current_pulls + amount)
	print("Pulls save response code: ", response[1])
