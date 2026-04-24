extends Node3D

var terrain: Node3D = null
var terrain_locked := true


func _ready():
	print("🌍 Forest loading...")

	terrain_locked = true

	# ─────────────────────────────────────────────
	# STEP 1: WAIT FOR SCENE + RENDER STABILITY
	# ─────────────────────────────────────────────
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw

	# ─────────────────────────────────────────────
	# STEP 2: FIND TERRAIN SAFELY
	# ─────────────────────────────────────────────
	terrain = find_child("MarchingSquaresTerrain", true, false) as Node3D

	if terrain == null:
		print("❌ Terrain not found")
		return

	print("✓ Terrain found - starting safe reset")

	# ─────────────────────────────────────────────
	# STEP 3: HARD PAUSE TERRAIN SYSTEM
	# ─────────────────────────────────────────────
	terrain.set_process(false)
	terrain.set_physics_process(false)
	terrain.visible = false

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# ─────────────────────────────────────────────
	# STEP 4: CLEAR YUGEN STATE (SAFE CALLS ONLY)
	# ─────────────────────────────────────────────
	_clear_terrain_safe()

	# ─────────────────────────────────────────────
	# STEP 5: GPU BUFFER RELEASE WINDOW
	# ─────────────────────────────────────────────
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# ─────────────────────────────────────────────
	# STEP 6: RE-ENABLE TERRAIN
	# ─────────────────────────────────────────────
	terrain.visible = true
	terrain.set_process(true)
	terrain.set_physics_process(true)

	# IMPORTANT: let engine breathe BEFORE generating again
	await get_tree().create_timer(0.1).timeout

	_force_rebuild()

	terrain_locked = false

	print("✓ Terrain FULLY stabilized")


# ─────────────────────────────────────────────
# SAFE CLEANUP
# ─────────────────────────────────────────────
func _clear_terrain_safe():
	if terrain == null:
		return

	print("🧹 Clearing terrain state...")

	if terrain.has_method("clear_cache"):
		terrain.call("clear_cache")

	if terrain.has_method("reset"):
		terrain.call("reset")

	if terrain.has_method("free_chunks"):
		terrain.call("free_chunks")


# ─────────────────────────────────────────────
# SAFE REBUILD (NO DOUBLE GENERATION)
# ─────────────────────────────────────────────
func _force_rebuild():
	if terrain == null:
		return

	if terrain_locked:
		print("⛔ Terrain locked, skipping rebuild")
		return

	print("🔄 Forcing terrain rebuild...")

	for method_name in [
		"update_terrain",
		"force_update",
		"queue_redraw",
		"regen",
		"rebuild",
		"generate"
	]:
		if terrain.has_method(method_name):
			terrain.call(method_name)
