extends Node

const SUPABASE_URL = "http://127.0.0.1:54321"
const SUPABASE_ANON_KEY = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

var auth_token: String = ""
var current_uid: int = 0
var current_user_id: String = ""

func _ready():
	pass

# Register new account AND create profile in one flow
func register(email: String, username: String, password: String) -> Dictionary:
	# Step 1: Create auth user
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
	
	# Check if registration succeeded
	if result.has("error"):
		print("Registration failed: ", result.error)
		return result
	
	if result.has("access_token"):
		# Step 2: Set auth token
		auth_token = result.access_token
		current_user_id = result.user.id
		print("Auth successful! User ID: ", current_user_id)
		
		# Step 3: Create player profile (wait for it to complete)
		var profile_result = await create_player_profile(username)
		
		if profile_result and profile_result.has("success") and profile_result.success:
			# Step 4: Give starter characters
			await give_starter_characters()
			print("Registration complete!")
			return {"success": true, "user": result.user}
		else:
			print("Profile creation failed: ", profile_result)
			return {"error": "Failed to create player profile"}
	
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

# Create player profile after successful registration
func create_player_profile(username: String) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token,
		"Prefer: return=representation"
	]
	
	# IMPORTANT: Include account_id to link to auth user
	var body = JSON.stringify({
		"account_id": current_user_id,  # This is CRITICAL!
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
		"saved_party": [1],
		"account_level": 1,
		"account_exp": 0,
		"world_level": 1,
		"gold": 0,
		"pulls": 0,
		"current_scene": "res://Scenes/small_village.tscn"  # Set default scene for new players
	})
	
	print("Creating profile with body: ", body)
	http.request(SUPABASE_URL + "/rest/v1/player_profile", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	var response_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	http.queue_free()
	
	print("Profile creation response code: ", response_code)
	print("Profile creation response: ", response_body)
	
	if response_code == 201 or response_code == 200:
		var result = JSON.parse_string(response_body)
		# Supabase returns an array, so we need to handle that
		if result is Array and result.size() > 0:
			print("Profile created successfully!")
			return {"success": true, "profile": result[0]}
		elif result is Dictionary:
			return {"success": true, "profile": result}
		else:
			return {"success": true, "profile": {}}
	else:
		return {"error": "HTTP " + str(response_code), "body": response_body}

# Give starter characters after profile creation
func give_starter_characters() -> void:
	# Wait a moment for the profile to be fully committed to database
	await get_tree().create_timer(1.0).timeout
	
	# Fetch profile with retry logic
	var max_retries = 5
	var retry_count = 0
	var profile_fetched = false
	var uid = 0
	
	while retry_count < max_retries and not profile_fetched:
		await fetch_player_profile()
		
		if GameManager.player_profile and GameManager.player_profile.has("uid"):
			uid = GameManager.player_profile.get("uid", 0)
			if uid != 0:
				profile_fetched = true
				print("Profile fetched successfully on attempt ", retry_count + 1, " with UID: ", uid)
			else:
				print("Profile has no UID on attempt ", retry_count + 1)
				retry_count += 1
				await get_tree().create_timer(0.5).timeout
		else:
			print("No profile found on attempt ", retry_count + 1)
			retry_count += 1
			await get_tree().create_timer(0.5).timeout
	
	if uid == 0:
		print("ERROR: No UID found after retries!")
		return
	
	print("Giving starter characters to UID: ", uid)
	
	# Give Manasan character (ID: 1)
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
		"current_exp": 0,
		"basic_level": 1,
		"skill_level": 1,
		"ult_level": 1,
		"talent_level": 1
	})
	http.request(SUPABASE_URL + "/rest/v1/player_characters", headers, HTTPClient.METHOD_POST, body)
	var response = await http.request_completed
	var response_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	http.queue_free()
	
	print("Manasan creation response code: ", response_code)
	print("Manasan creation response: ", response_body)
	
	if response_code != 201 and response_code != 200:
		print("ERROR: Failed to give Manasan character!")
		return
	
	# Also update party_loadouts to ensure Manasan is in all loadouts
	var http2 = HTTPRequest.new()
	add_child(http2)
	var headers2 = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	var body2 = JSON.stringify({
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
	http2.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers2, HTTPClient.METHOD_PATCH, body2)
	var response2 = await http2.request_completed
	http2.queue_free()
	print("Party loadouts updated: ", response2[3].get_string_from_utf8())
	
	# Reload profile to get updated data
	await get_tree().create_timer(0.5).timeout
	await fetch_player_profile()
	print("Final profile after giving characters: ", GameManager.player_profile)
	
	# Verify character was added
	await fetch_player_characters()
	print("Characters after giving Manasan: ", GameManager.player_characters)

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
		
		# FIX: Check if the saved scene is hubtown and replace with small_village
		var saved_scene = GameManager.player_profile.get("current_scene", "")
		if saved_scene == "res://Scenes/hubtown.tscn" or saved_scene == "hubtown.tscn":
			print("WARNING: Found hubtown reference, replacing with small_village")
			GameManager.player_profile["current_scene"] = "res://Scenes/small_village.tscn"
			# Optionally save this change back to database
			await update_current_scene_to_small_village()
		
		await fetch_player_characters()
		GameManager.load_character_resources()
		load_player_state()
		print("Profile, characters and state loaded!")

# New function to update current scene in database
func update_current_scene_to_small_village() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0:
		print("Cannot update scene - no UID")
		http.queue_free()
		return
	
	var body = JSON.stringify({
		"current_scene": "res://Scenes/small_village.tscn"
	})
	
	print("Updating current_scene to small_village for UID: ", uid)
	http.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	var response = await http.request_completed
	http.queue_free()
	
	var response_code = response[1]
	if response_code >= 200 and response_code < 300:
		print("Successfully updated current_scene to small_village")
	else:
		print("Failed to update current_scene: ", response_code)

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
	
	# Convert to integer properly
	var current_loadout = 1
	if typeof(current_loadout_raw) == TYPE_FLOAT:
		current_loadout = int(current_loadout_raw)
	elif typeof(current_loadout_raw) == TYPE_INT:
		current_loadout = current_loadout_raw
	elif typeof(current_loadout_raw) == TYPE_STRING:
		current_loadout = int(current_loadout_raw)
	else:
		current_loadout = 1
	
	var party_loadouts = profile.get("party_loadouts", {})
	
	var party_ids = []
	
	if party_loadouts is Dictionary:
		var loadout_key = str(current_loadout)
		if party_loadouts.has(loadout_key):
			var loadout_data = party_loadouts[loadout_key]
			if loadout_data is Array:
				party_ids = loadout_data
				print("Loading party from current loadout ", current_loadout, ": ", party_ids)
		else:
			print("Loadout key not found: ", loadout_key)
			print("Available keys: ", party_loadouts.keys())
	
	print("Parsed party IDs: ", party_ids)
	
	if party_ids.size() > 0:
		var party = []
		var slot_party = [null, null, null, null]
		
		for i in range(min(party_ids.size(), 4)):
			var char_id = party_ids[i]
			if char_id != null and char_id != 0:
				# Handle float IDs (1.0 -> 1)
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
			print("No valid characters found in loadout")
	else:
		print("No party found in current loadout ", current_loadout)

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
		"character_id": 6,
		"current_level": 1,
		"current_exp": 0,
		"basic_level": 1,
		"skill_level": 1,
		"ult_level": 1,
		"talent_level": 1
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

# Save checkpoint function (fixed)
func save_checkpoint(checkpoint_id: String, scene_name: String, pos: Vector3):
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var uid = GameManager.player_profile.get("uid", 0)
	
	# IMPORTANT: Ensure scene_name has .tscn extension
	var full_scene_path = scene_name
	if not full_scene_path.ends_with(".tscn"):
		full_scene_path = "res://Scenes/" + scene_name + ".tscn"
	
	var body = JSON.stringify({
		"last_checkpoint": checkpoint_id,
		"current_scene": full_scene_path,
		"last_pos_x": pos.x,
		"last_pos_y": pos.y,
		"last_pos_z": pos.z
	})
	
	print("Saving checkpoint - Scene: ", full_scene_path, " Position: ", pos)
	
	http.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	var response = await http.request_completed
	http.queue_free()
	
	# Update local profile too
	GameManager.player_profile["last_checkpoint"] = checkpoint_id
	GameManager.player_profile["current_scene"] = full_scene_path
	GameManager.player_profile["last_pos_x"] = pos.x
	GameManager.player_profile["last_pos_y"] = pos.y
	GameManager.player_profile["last_pos_z"] = pos.z
	
	print("Checkpoint saved: ", checkpoint_id, " in ", full_scene_path)

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

# Auto-save player state (FIXED - proper connection handling)
func save_current_scene_and_position():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("⚠ Cannot save - no player found!")
		return
	
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("⚠ Cannot save - no current scene!")
		return
	
	var scene_path = current_scene.scene_file_path
	if scene_path == "" or scene_path == null:
		print("⚠ Cannot save - scene has no file path!")
		return
	
	var pos = player.global_position
	
	# Update local cache
	GameManager.player_profile["current_scene"] = scene_path
	GameManager.player_profile["last_pos_x"] = pos.x
	GameManager.player_profile["last_pos_y"] = pos.y
	GameManager.player_profile["last_pos_z"] = pos.z
	
	print("💾 Saving state - Scene: ", scene_path, " Position: ", pos)
	
	# Save to database
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	var uid = GameManager.player_profile.get("uid", 0)
	if uid == 0:
		print("⚠ Cannot save - no UID found!")
		http.queue_free()
		return
	
	var body = JSON.stringify({
		"current_scene": scene_path,
		"last_pos_x": pos.x,
		"last_pos_y": pos.y,
		"last_pos_z": pos.z
	})
	
	var error = http.request(SUPABASE_URL + "/rest/v1/player_profile?uid=eq." + str(int(uid)), headers, HTTPClient.METHOD_PATCH, body)
	
	if error != OK:
		print("⚠ Failed to send save request!")
		http.queue_free()
		return
	
	# Wait for response
	var response = await http.request_completed
	var response_code = response[1]
	http.queue_free()
	
	if response_code >= 200 and response_code < 300:
		print("✓ Auto-save successful: ", scene_path, " at ", pos)
	else:
		print("⚠ Auto-save failed with code: ", response_code)

# Keep old function name for compatibility
func auto_save_player_state():
	await save_current_scene_and_position()

# Debug function to check characters
func debug_check_characters():
	print("=== DEBUG: Checking characters in database ===")
	await fetch_player_characters()
	print("Characters in DB: ", GameManager.player_characters)
	
	if GameManager.player_characters.size() == 0:
		print("WARNING: No characters found in database!")
		print("Profile UID: ", GameManager.player_profile.get("uid", 0) if GameManager.player_profile else "No profile")
	else:
		for char in GameManager.player_characters:
			print("Character: ID=", char.get("character_id"), " Level=", char.get("current_level"))
