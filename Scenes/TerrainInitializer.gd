extends Node3D

func _ready():
	print("🌍 World Loading...")
	await get_tree().process_frame
	
	var terrain = find_child("MarchingSquaresTerrain", true, false)
	if not terrain:
		print("❌ Terrain not found")
		return
	
	print("✓ Found terrain, applying soft reset...")
	
	# Just update shader parameters - don't rebuild meshes
	if terrain.has_method("force_batch_update"):
		terrain.force_batch_update()
		print("✓ Terrain materials refreshed")
	
	# Wait for rendering
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("✓ World ready!")
