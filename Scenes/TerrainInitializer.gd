extends Node3D

func _ready():

	# ==================================
	# EXISTING USER: LOAD SAVED POSITION
	# ==================================
	if GameManager.has_saved_position:
		$Player.global_position = GameManager.saved_player_position
		print("✓ Loaded saved position:", GameManager.saved_player_position)

	# ==================================
	# NEW USER / TELEPORT SPAWN
	# ==================================
	elif GameManager.next_spawn != "" and has_node(GameManager.next_spawn):
		var spawn = get_node(GameManager.next_spawn)
		$Player.global_position = spawn.global_position
		$Player.global_rotation = spawn.global_rotation
		print("✓ Spawned at:", GameManager.next_spawn)

	# ==================================
	# DEFAULT FALLBACK
	# ==================================
	else:
		$Player.global_position = $SpawnPoint.global_position
		$Player.global_rotation = $SpawnPoint.global_rotation
		print("✓ Default spawn used")

	# Clear one-time spawn request
	GameManager.next_spawn = ""

	# ==================================
	# WORLD LOADING
	# ==================================
	print("🌍 World Loading...")
	await get_tree().process_frame

	var terrain = find_child("MarchingSquaresTerrain", true, false)

	if not terrain:
		print("❌ Terrain not found")
		return

	print("✓ Found terrain, applying soft reset...")

	if terrain.has_method("force_batch_update"):
		terrain.force_batch_update()
		print("✓ Terrain materials refreshed")

	await get_tree().process_frame
	await get_tree().process_frame

	print("✓ World ready!")
