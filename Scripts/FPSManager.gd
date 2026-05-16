extends CanvasLayer

# UI Elements (Assumes a Label node is a child of this CanvasLayer)
@onready var fps_label: Label = $Control/FPSLabel

func _ready() -> void:
	# Ensure the overlay stays visible on top of game graphics
	layer = 100 
	
	# Optional: Initialize with your target default FPS limit
	set_fps_limit(60)

func _process(_delta: float) -> void:
	# Retrieves the current engine FPS
	var current_fps = Performance.get_monitor(Performance.TIME_FPS)
	fps_label.text = "FPS: " + str(round(current_fps))

# Call this function from any menu or settings page to limit the FPS
func set_fps_limit(limit: int) -> void:
	# A limit of 0 means uncapped FPS
	Engine.max_fps = limit
