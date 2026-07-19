extends Control

@onready var grid = $Panel/Margin/VBox/Scroll/GridContainer
@onready var close_btn = $Panel/Margin/VBox/Header/CloseBtn

var slot_scene = preload("res://Scenes/InventorySlot.tscn")

func _ready():
	close_btn.pressed.connect(_on_close_pressed)
	# Auto-open when loaded as a scene (PauseMenu navigates here directly)
	open_inventory()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func open_inventory():
	visible = true
	refresh_inventory()

func refresh_inventory():
	# Clear the old grid completely
	for child in grid.get_children():
		child.queue_free()

	SupabaseManager.fetch_inventory_items(_on_items_received)

func _on_items_received(data: Array):
	for item in data:
		var slot = slot_scene.instantiate()
		grid.add_child(slot)

		var id  = int(item["item_id"])
		var qty = int(item["quantity"])

		slot.setup_slot(id, qty)

func _on_close_pressed() -> void:
	GameManager.pending_zone = GameManager.get_return_scene()
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")
