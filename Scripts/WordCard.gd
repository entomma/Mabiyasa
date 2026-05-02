extends Resource
class_name WordCard

@export var card_id: int
@export var kapampangan_text: String
@export var english_hint: String
@export var example_sentence: String  # Add this line
@export var card_type: String  # "Action", "Noun", "Adjective", "Number"
@export var category: String   # "Domestic", "Nature", "Quantity", "Pronoun"
@export var texture: Texture2D
