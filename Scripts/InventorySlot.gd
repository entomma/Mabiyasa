extends Button

@onready var icon_rect = $Icon
@onready var qty_label = $QtyBackground/QuantityLabel

# Map the integer item_ids from your database to your textures
# Example: 1 = Wood, 2 = Fish, 3 = Stone, etc.
var item_database = {
	1: preload("res://Assets/wood.jpg"),
	2: preload("res://Assets/mouse.png") # Replace with actual fish/item assets later
}

func setup_slot(item_id: int, quantity: int):
	qty_label.text = str(quantity)
	
	if item_database.has(item_id):
		icon_rect.texture = item_database[item_id]
