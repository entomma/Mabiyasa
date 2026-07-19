extends Node

@onready var current_zone: Node3D = $CurrentZone

func _ready() -> void:
	GameManager.zone_container = current_zone
	var zone_to_load = GameManager.pending_zone if GameManager.pending_zone != "" else "res://Scenes/small_village.tscn"
	GameManager.pending_zone = ""
	GameManager.load_zone(zone_to_load, GameManager.next_spawn)
