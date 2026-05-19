extends Control

@onready var grid = $Panel/Margin/VBox/Scroll/GridContainer
@onready var close_btn = $Panel/Margin/VBox/Header/CloseBtn

var slot_scene = preload("res://Scenes/InventorySlot.tscn")

func _ready():
	visible = false
	close_btn.pressed.connect(func(): visible = false)

func open_inventory():
	visible = true
	refresh_inventory()

func refresh_inventory():
	# Clear the old grid completely
	for child in grid.get_children():
		child.queue_free()
	
	# Fetch only items (ignoring cards)
	SupabaseManager.fetch_inventory_items(_on_items_received)

func _on_items_received(data: Array):
	for item in data:
		var slot = slot_scene.instantiate()
		grid.add_child(slot)
		
		# Your DB uses integers for item_id and quantity
		var id = int(item["item_id"])
		var qty = int(item["quantity"])
		
		slot.setup_slot(id, qty)
