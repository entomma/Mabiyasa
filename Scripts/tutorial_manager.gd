extends Node

signal tutorial_step_completed(step_name: String)
signal step_changed(step_name: String)
signal progress_updated(current: float, target: float)
signal tutorial_visibility_changed(is_visible: bool)

var progress : Dictionary = {
	"intro": false,
	"movement": false,
	"camera": false,
	"interact": false,
	"dialogue": false,
	"inventory": false,
	"character_menu": false,
	"quest": false,
	"battle": false
}

var current_active_step: String = "intro"
var current_user_id: String = "" # Tracks who is currently logged in

var current_step: String:
	get:
		return current_active_step
	set(value):
		current_active_step = value

var movement_allowed: bool = false
var camera_allowed: bool = false
var sprint_allowed: bool = false
var interact_allowed: bool = false

var walk_distance: float = 0.0
const TARGET_WALK_DISTANCE: float = 25.0 

var camera_turned_amount: float = 0.0
const TARGET_CAMERA_TURN: float = 5.0 


func _ready() -> void:
	# Default to intro state on boot before login
	update_permissions()


func _input(event: InputEvent) -> void:
	# 1. F12 Reset (Debug Only)
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			reset_all()
			get_tree().reload_current_scene()
			return

	# 2. Alt-to-Free Mouse (Unlocked ONLY after the tutorial is "finished")
	if current_active_step == "finished":
		if event is InputEventKey and event.keycode == KEY_ALT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Helper to get the unique save path for the logged-in user
func get_save_path() -> String:
	if current_user_id == "":
		return "user://tutorial_save_guest.cfg"
	return "user://tutorial_save_" + current_user_id + ".cfg"


func is_completed(step_name: String) -> bool:
	if progress.has(step_name):
		return progress[step_name]
	return false


func start_step(step_name: String) -> void:
	if is_completed(step_name):
		return
		
	current_active_step = step_name
	update_permissions()
	step_changed.emit(step_name)


func start_tutorial() -> void:
	start_step("movement")


func change_step(new_step: String) -> void:
	start_step(new_step)


func complete_step(step_name: String) -> void:
	if progress.has(step_name) and progress[step_name] == false:
		progress[step_name] = true
		tutorial_step_completed.emit(step_name)


func update_permissions() -> void:
	var is_tutorial_active = (current_active_step != "intro" and current_active_step != "" and current_active_step != "finished")
	tutorial_visibility_changed.emit(is_tutorial_active)
	
	match current_active_step:
		"intro", "":
			movement_allowed = false
			camera_allowed = false
			sprint_allowed = false
			interact_allowed = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		"movement":
			movement_allowed = true 
			camera_allowed = false
			sprint_allowed = false
			interact_allowed = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		"camera":
			movement_allowed = true
			camera_allowed = true 
			sprint_allowed = false
			interact_allowed = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		"sprint":
			movement_allowed = true
			camera_allowed = true
			sprint_allowed = true 
			interact_allowed = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		"interact":
			movement_allowed = true
			camera_allowed = true
			sprint_allowed = true
			interact_allowed = true 
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		"completed", "finished":
			movement_allowed = true
			camera_allowed = true
			sprint_allowed = true
			interact_allowed = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_:
			movement_allowed = true
			camera_allowed = true
			sprint_allowed = true
			interact_allowed = true


func record_walk(amount: float) -> void:
	if current_active_step != "movement": return
	walk_distance += amount
	progress_updated.emit(walk_distance, TARGET_WALK_DISTANCE)
	if walk_distance >= TARGET_WALK_DISTANCE:
		complete_step("movement")
		change_step("camera")


func record_camera_turn(amount: float) -> void:
	if current_active_step != "camera": return
	camera_turned_amount += amount
	progress_updated.emit(camera_turned_amount, TARGET_CAMERA_TURN)
	if camera_turned_amount >= TARGET_CAMERA_TURN:
		complete_step("camera")
		change_step("sprint")


func record_sprint() -> void:
	if current_active_step != "sprint": return
	complete_step("sprint")
	change_step("interact")


func record_interaction() -> void:
	if current_active_step != "interact": return
	complete_step("interact")
	change_step("completed")
	save_tutorial_status()
	
	await get_tree().create_timer(4.0).timeout
	change_step("finished")


# --- DYNAMIC SAVE / LOAD LOGIC ---

func save_tutorial_status() -> void:
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", true)
	var _err = config.save(get_save_path())


# Call this function when the user successfully logs in!
func load_tutorial_status(user_id: String) -> void:
	current_user_id = user_id
	
	var config = ConfigFile.new()
	var err = config.load(get_save_path())
	
	if err == OK:
		var is_completed_saved = config.get_value("tutorial", "completed", false)
		if is_completed_saved:
			current_active_step = "finished"
			for key in progress.keys():
				progress[key] = true
		else:
			set_fresh_state()
	else:
		set_fresh_state()
		
	update_permissions()


func set_fresh_state() -> void:
	current_active_step = "intro"
	walk_distance = 0.0
	camera_turned_amount = 0.0
	for key in progress.keys():
		progress[key] = false


func reset_all() -> void:
	set_fresh_state()
	
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists(get_save_path().get_file()):
		dir.remove(get_save_path().get_file())
		
	update_permissions()
