extends Resource
class_name WordCard

@export var card_id: int               # Unique ID for Postgres/PHP 
@export var kapampangan_text: String    # e.g., "Mandilu" 
@export var english_hint: String        # e.g., "To bathe" 
@export var card_type: String           # "Action", "Noun", or "Number" 
@export var category: String            # "Domestic", "Nature", "Quantity" 
@export var texture: Texture2D          # The artwork for the card
