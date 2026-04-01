extends Node

const SUPABASE_URL = "http://127.0.0.1:54321"
const SUPABASE_ANON_KEY = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"  # paste your anon key

var auth_token: String = ""
var current_uid: int = 0
var current_user_id: String = ""

func _ready():
	pass

# Register new account
func register(email: String, _username: String, password: String) -> Dictionary:
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
	print("Register response: ", result)  # ADD THIS LINE
	return result

#login
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

# Create player profile after register
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
		"username": username
	})
	
	http.request(SUPABASE_URL + "/rest/v1/player_profile", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	http.queue_free()
	
	var response_body = response[3].get_string_from_utf8()
	print("Profile creation response: ", response_body)
	
	if response_body == "":
		return {"success": true}
	
	var result = JSON.parse_string(response_body)
	if result == null:
		return {"success": true}
	
	# Give Manasan after profile created
	await give_starter_characters()
	
	return result

# Give starter characters after profile creation
func give_starter_characters() -> void:
	await fetch_player_profile()
	
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0:
		print("No UID found!")
		return
	
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
	
	# Save Manasan as default party
	var http2 = HTTPRequest.new()
	add_child(http2)
	var headers2 = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	var body2 = JSON.stringify({
		"saved_party": [1]
	})
	http2.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers2, HTTPClient.METHOD_PATCH, body2)
	var response2 = await http2.request_completed
	http2.queue_free()
	print("Default party saved: ", response2[3].get_string_from_utf8())
	
	# Reload profile to get updated saved_party
	await fetch_player_profile()
	
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
		
		await fetch_player_characters()
		GameManager.load_character_resources()
		load_player_state()  # ← ADD THIS
		print("Profile, characters and state loaded!")

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
	
	var party_ids = profile.get("saved_party", [])
	print("saved_party from DB: ", party_ids)
	
	# Handle string format from Postgres e.g. "{1,0,3,0}"
	var ids_array = []
	if party_ids is Array:
		ids_array = party_ids
	elif party_ids is String:
		var cleaned = party_ids.replace("{", "").replace("}", "").strip_edges()
		if cleaned != "":
			for id_str in cleaned.split(","):
				ids_array.append(int(id_str.strip_edges()))
	
	print("Parsed party IDs: ", ids_array)
	
	if ids_array.size() > 0:
		var party = []
		var slot_party = [null, null, null, null]
		
		for i in range(min(ids_array.size(), 4)):
			var char_id = int(ids_array[i])
			if char_id != 0:  # 0 = empty slot
				var char_resource = GameManager.get_character_by_id(char_id)  # Already duplicated
				if char_resource:
					slot_party[i] = char_resource
					party.append(char_resource)
					print("Loaded slot ", i, ": ", char_resource.character_name)
		
		if party.size() > 0:
			GameManager.player_party = party
			GameManager.saved_party_slots = slot_party
			print("Party loaded: ", party.size(), " characters")
	else:
		print("No saved party found!")

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
		"character_id": 6,  # Tanud's ID
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
	
	# Update local profile too
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
