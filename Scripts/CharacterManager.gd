extends Node
## CharacterManager
## Owns: the account's roster — raw DB rows (player_characters) and the
## resolved CharacterData resources built from them. PartyManager only
## stores *which* of these are deployed; it never duplicates roster data.

signal characters_updated

var player_characters: Array = []          # raw rows from Supabase
var owned_character_resources: Array = []  # resolved CharacterData

## Called by SupabaseManager after fetching the roster.
func set_characters(rows: Array) -> void:
	player_characters = rows
	load_character_resources()
	characters_updated.emit()

func load_character_resources() -> void:
	owned_character_resources.clear()
	for db_char in player_characters:
		var char_id = db_char.get("character_id", 0)
		var char_resource = get_character_by_id(char_id)
		if char_resource:
			char_resource.current_level = db_char.get("current_level", 1)
			char_resource.current_exp = db_char.get("current_exp", 0)
			owned_character_resources.append(char_resource)
	print("Loaded character resources: ", owned_character_resources.size())

func get_character_by_id(id: int) -> CharacterData:
	var path = "res://Resources/Characters/"
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".tres"):
			var char_data = load(path + f)
			if char_data is CharacterData and char_data.character_id == id:
				return char_data.duplicate()
	return null
