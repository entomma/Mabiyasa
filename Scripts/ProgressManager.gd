extends Node

# ============================================================
# PLAYER PROGRESSION
# Handles:
# - Account Level
# - EXP
# - Story Flags
# - Lesson Progress
# - Quest Progress
#
# Does NOT handle:
# - Inventory
# - Characters
# - Party
# ============================================================

signal account_level_changed(level: int)
signal exp_changed(current: int, max: int)
signal flag_changed(flag: StringName, value: bool)

# ==========================
# ACCOUNT PROGRESSION
# ==========================

var account_level: int = 1
var exp: int = 0
var exp_max: int = 100

# ==========================
# STORY / LESSON FLAGS
# ==========================

var flags: Dictionary = {}

# ============================================================
# LOAD DATA FROM SUPABASE
# ============================================================

func apply_profile(profile: Dictionary) -> void:

	account_level = profile.get("account_level", 1)
	exp = profile.get("account_exp", 0)
	exp_max = profile.get("account_exp_max", 100)

	# Future database column
	flags = profile.get("progress", {}).duplicate(true)

	account_level_changed.emit(account_level)
	exp_changed.emit(exp, exp_max)

# ============================================================
# EXP
# ============================================================

func add_exp(amount: int):

	exp += amount

	while exp >= exp_max:

		exp -= exp_max
		account_level += 1

		account_level_changed.emit(account_level)

	exp_changed.emit(exp, exp_max)

# ============================================================
# FLAGS
# ============================================================

func has_flag(flag: StringName) -> bool:

	return flags.get(flag, false)


func set_flag(flag: StringName):

	if has_flag(flag):
		return

	flags[flag] = true

	flag_changed.emit(flag, true)


func clear_flag(flag: StringName):

	if !flags.has(flag):
		return

	flags.erase(flag)

	flag_changed.emit(flag, false)


func toggle_flag(flag: StringName):

	if has_flag(flag):
		clear_flag(flag)
	else:
		set_flag(flag)

# ============================================================
# SAVE DATA
# ============================================================

func get_progress_data() -> Dictionary:

	return {
		"account_level": account_level,
		"account_exp": exp,
		"account_exp_max": exp_max,
		"progress": flags
	}
