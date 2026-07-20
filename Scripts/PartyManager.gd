extends Node
## PartyManager
## Owns: the currently deployed battle party, and the account's saved party
## loadout configurations. Battle.gd reads `player_party` for combat; UI
## screens (PartySelect) read/write loadouts through here instead of poking
## a shared profile dict.

const MAX_LOADOUTS := 6

signal party_deployed(party: Array)

var player_party: Array = []             # deployed CharacterData for battle
var party_loadouts: Dictionary = {}      # loadout_key(String) -> Array[char_id or null]
var current_loadout: int = 1

## Deploys a party for battle. Called by PartySelect when the player confirms.
func set_party(party: Array) -> void:
	player_party = party
	print("Party saved: ", player_party.size(), " characters")
	for character in player_party:
		print(" - ", character.character_name)
	party_deployed.emit(player_party)

## Called by SupabaseManager (or AccountManager.apply_profile caller) after a
## profile fetch, to seed loadouts owned by this manager.
func apply_loadouts(saved_loadouts: Dictionary, saved_current_loadout: int) -> void:
	party_loadouts.clear()
	if saved_loadouts is Dictionary:
		for key in saved_loadouts:
			party_loadouts[str(key)] = saved_loadouts[key]

	for i in range(1, MAX_LOADOUTS + 1):
		var key = str(i)
		if not party_loadouts.has(key) or not (party_loadouts[key] is Array):
			party_loadouts[key] = [null, null, null, null]
		else:
			party_loadouts[key] = party_loadouts[key].duplicate()

	current_loadout = clampi(saved_current_loadout, 1, MAX_LOADOUTS)

func save_loadout(loadout_num: int, party_ids: Array) -> void:
	party_loadouts[str(loadout_num)] = party_ids

func get_loadout(loadout_num: int) -> Array:
	var key = str(loadout_num)
	if party_loadouts.has(key):
		return party_loadouts[key]
	return [null, null, null, null]

## Returns the dict of fields this manager is responsible for persisting.
func get_persistable_fields() -> Dictionary:
	return {
		"party_loadouts": party_loadouts.duplicate(),
		"current_loadout": current_loadout,
	}
