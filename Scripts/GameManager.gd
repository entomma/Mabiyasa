extends Node
## GameManager
## Owns: scene/zone loading, transitions, and transient combat flags.
## It no longer holds player data — see AccountManager, CharacterManager,
## PartyManager, ProgressManager, and GachaManager for that.
var next_spawn: String = "default"
var in_combat: bool = false
var active_enemy = null
var active_enemy_data = null
var transition: Node = null

var origin_scene: String = "res://Scenes/small_village.tscn"
var zone_container: Node = null
var current_zone_path: String = ""
var pending_zone: String = ""

func load_zone(zone_path: String, spawn_point: String = "") -> void:
	if zone_container == null:
		push_error("load_zone called before Game.tscn registered its zone container")
		return

	next_spawn = spawn_point

	if transition:
		await transition.fade_to_black()

	for child in zone_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	var zone_scene: PackedScene = load(zone_path)
	if zone_scene == null:
		push_error("Zone not found: " + zone_path)
		return

	var zone_instance = zone_scene.instantiate()
	zone_container.add_child(zone_instance)
	current_zone_path = zone_path
	origin_scene = zone_path

	if transition:
		transition.fade_in()

func _ready():
	var transition_scene = preload("res://Scenes/Transition.tscn")
	transition = transition_scene.instantiate()
	transition.add_to_group("transition")
	add_child(transition)

func start_combat(enemy, enemy_data):
	if in_combat:
		return
	in_combat = true
	active_enemy      = enemy
	active_enemy_data = enemy_data

	var current = get_tree().current_scene
	if current and current.scene_file_path != "":
		origin_scene = current.scene_file_path
		set_meta("last_scene", origin_scene)
		print("Origin scene stored: ", origin_scene)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)

	transition.start_transition_fade()

func end_combat():
	in_combat         = false
	active_enemy      = null
	active_enemy_data = null
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)

# ─── NEW: Get the scene to return to after menus ───
func get_return_scene() -> String:
	if has_meta("return_scene"):
		var scene = get_meta("return_scene")
		# Clear it after reading so we don't use stale data
		remove_meta("return_scene")
		return scene
	# Fallback to origin_scene or default village
	return origin_scene if origin_scene != "" else "res://Scenes/small_village.tscn"
