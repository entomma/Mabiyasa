extends Node
## AccountManager
## Owns: the logged-in account's identity (uid, username), the current
## scene/checkpoint the session is in, and the last saved world position.
##
## Nothing else should hold a private copy of these fields. SupabaseManager
## writes into this manager after a fetch; everyone else reads from it.
signal profile_loaded(profile: Dictionary)
signal position_saved(pos: Vector3)
signal logged_out
var uid: int = 0
var username: String = ""
var current_scene: String = ""
var last_checkpoint: String = "start"
var _saved_position: Vector3 = Vector3.ZERO
var has_saved_position: bool = false
var saved_position: Vector3:
	get:
		return _saved_position
func is_logged_in() -> bool:
	return uid != 0
## Safely reads a field from a Supabase row dict. Dictionary.get() only
## falls back to `default` when the key is absent; Supabase frequently sends
## the key back with an explicit JSON null value instead, which .get() would
## pass through as-is. This treats null the same as "missing".
func _get_str(data: Dictionary, key: String, default: String = "") -> String:
	var v = data.get(key, default)
	return default if v == null else str(v)
func _get_num(data: Dictionary, key: String, default: float = 0.0) -> float:
	var v = data.get(key, default)
	return default if v == null else float(v)
## Called by SupabaseManager right after a profile row is fetched.
## Only pulls the fields AccountManager is responsible for; other managers
## (ProgressManager, GachaManager, PartyManager) read the same raw dict
## themselves for their own fields.
func apply_profile(data: Dictionary) -> void:
	if data == null:
		return
	uid = int(_get_num(data, "uid", 0))
	username = _get_str(data, "username", "")
	last_checkpoint = _get_str(data, "last_checkpoint", "start")
	var saved_scene = _get_str(data, "current_scene", "")
	current_scene = saved_scene if saved_scene != "" else "res://Scenes/small_village.tscn"
	var px = _get_num(data, "last_pos_x", 0)
	var py = _get_num(data, "last_pos_y", 0)
	var pz = _get_num(data, "last_pos_z", 0)
	var pos = Vector3(px, py, pz)
	if pos != Vector3.ZERO:
		_saved_position = pos
		has_saved_position = true
	profile_loaded.emit(data)
func set_saved_position(pos: Vector3) -> void:
	if pos != Vector3.ZERO:
		_saved_position = pos
		has_saved_position = true
		position_saved.emit(pos)
func set_current_scene(scene_path: String) -> void:
	current_scene = scene_path
func set_last_checkpoint(checkpoint_id: String) -> void:
	last_checkpoint = checkpoint_id
## Returns the dict of fields AccountManager is responsible for persisting.
## SupabaseManager calls this when it needs to write position/scene back to
## the DB — it should never reach into another manager's private fields.
func get_persistable_fields() -> Dictionary:
	return {
		"current_scene": current_scene,
		"last_checkpoint": last_checkpoint,
		"last_pos_x": _saved_position.x,
		"last_pos_y": _saved_position.y,
		"last_pos_z": _saved_position.z,
	}
func clear() -> void:
	uid = 0
	username = ""
	current_scene = ""
	last_checkpoint = "start"
	_saved_position = Vector3.ZERO
	has_saved_position = false
	logged_out.emit()
