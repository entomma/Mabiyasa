extends Node
## ProgressManager
## Owns: account-level progression (level, exp, exp_max). Currently
## display-only (fed by whatever the profile row contains), but this is
## where XP-granting logic should live once it exists — not in PauseMenu
## or scattered across gameplay scripts.

signal progress_updated

var level: int = 1
var exp: int = 0
var exp_max: int = 10000
var account_level: int = 1

func apply_profile(data: Dictionary) -> void:
	if data == null:
		return
	level = int(data.get("level", 1))
	exp = int(data.get("exp", 0))
	exp_max = int(data.get("exp_max", 10000))
	account_level = int(data.get("account_level", 1))
	progress_updated.emit()

func get_persistable_fields() -> Dictionary:
	return {
		"level": level,
		"exp": exp,
		"exp_max": exp_max,
		"account_level": account_level,
	}
