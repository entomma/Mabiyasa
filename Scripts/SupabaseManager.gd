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
