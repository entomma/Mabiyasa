extends Node3D
@export var player_scene: PackedScene

func _ready():
	$Player.global_position = $SpawnPoint.global_position
	$Player.global_rotation = $SpawnPoint.global_rotation

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
