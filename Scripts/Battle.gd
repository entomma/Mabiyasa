extends Node3D

# UI References
@onready var card_panel = $BattleUI/CardPanel
@onready var card_grid = $BattleUI/CardPanel/CardGrid
@onready var affix_panel = $BattleUI/CardPanel/AffixPanel
@onready var prefix_btn = $BattleUI/CardPanel/AffixPanel/PrefixBtn
@onready var suffix_btn = $BattleUI/CardPanel/AffixPanel/SuffixBtn
@onready var connector_btn = $BattleUI/CardPanel/AffixPanel/ConnectorBtn
@onready var other_btn = $BattleUI/CardPanel/AffixPanel/OtherBtn
@onready var sentence_bar = $BattleUI/CardPanel/SentenceBar
@onready var sentence_container = $BattleUI/CardPanel/SentenceBar/SentenceContainer
@onready var submit_btn = $BattleUI/CardPanel/SentenceBar/SubmitButton
@onready var turn_order_ui = $BattleUI/TurnOrder
@onready var total_damage_label = $BattleUI/TotalDamage/TotalDamageNumber
@onready var char_portraits = $BattleUI/BottomLeft/CharPortraits
@onready var skill_buttons = $BattleUI/BottomRight
@onready var basic_btn = $BattleUI/BottomRight/BasicButton
@onready var skill_btn = $BattleUI/BottomRight/SkillButton
@onready var sp_stars = $BattleUI/BottomRight/SPStars
@onready var camera = $Camera3D

# Dynamic ult buttons storage
var ult_buttons: Array = []
var portrait_containers: Array = []

# Battle state
var turn_queue: Array = []
var current_turn_index: int = 0
var current_character: CharacterData = null
var current_skill: SkillData = null
var hand: Array = []
var sentence: Array = []
var total_damage_dealt: int = 0
var current_sp: int = 3
var max_sp: int = 5
var enemies: Array = []
var is_player_turn: bool = true

var current_affix_filter: String = ""

func _ready():
	# Fade in
	var transition = get_tree().get_first_node_in_group("transition")
	if transition:
		transition.fade_in()
	
	# Connect skill buttons
	basic_btn.pressed.connect(_on_basic_pressed)
	skill_btn.pressed.connect(_on_skill_pressed)
	submit_btn.pressed.connect(_on_submit_pressed)
	
	# Connect affix buttons
	prefix_btn.pressed.connect(_on_affix_pressed.bind("prefix"))
	suffix_btn.pressed.connect(_on_affix_pressed.bind("suffix"))
	connector_btn.pressed.connect(_on_affix_pressed.bind("connector"))
	other_btn.pressed.connect(_on_affix_pressed.bind("other"))
	
	# Make circular skill buttons
	make_circular_button(basic_btn, Color(0.72, 0.58, 0.42))
	make_circular_button(skill_btn, Color(0.85, 0.35, 0.28))
	
	# Hide panels
	card_panel.visible = false
	skill_buttons.visible = false
	
	# FIX: Set card panel to semi-transparent dark instead of pitch black
	setup_card_panel_background()
	
	setup_enemies()
	build_turn_queue()
	setup_character_portraits()
	setup_battle_sprites()
	draw_hand()
	start_battle()
	
	# FIX: Ensure camera is positioned correctly to see the battle
	if camera:
		camera.position = Vector3(0, 3, 8)
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)

func setup_card_panel_background():
	# Make card panel semi-transparent dark instead of pitch black
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)  # Dark blue-gray with 85% opacity
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	card_panel.add_theme_stylebox_override("panel", style)

func setup_character_portraits():
	# Clear existing portraits
	for child in char_portraits.get_children():
		child.queue_free()
	
	ult_buttons.clear()
	portrait_containers.clear()
	
	# Create portrait + ult button for each party member
	for i in range(GameManager.player_party.size()):
		var char_data = GameManager.player_party[i]
		
		# Create portrait container
		var portrait_container = VBoxContainer.new()
		portrait_container.name = "Portrait" + str(i + 1)
		portrait_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait_container.custom_minimum_size = Vector2(100, 140)
		
		# Create portrait texture
		var portrait = TextureRect.new()
		portrait.name = "PortraitTexture"
		portrait.custom_minimum_size = Vector2(80, 80)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		if char_data.splash_art:
			portrait.texture = char_data.splash_art
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		else:
			# Placeholder color based on element
			var placeholder = ColorRect.new()
			placeholder.custom_minimum_size = Vector2(80, 80)
			placeholder.color = Color(0.3, 0.3, 0.3)
			portrait.add_child(placeholder)
		
		portrait_container.add_child(portrait)
		
		# Create character name label
		var name_lbl = Label.new()
		name_lbl.text = char_data.character_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		portrait_container.add_child(name_lbl)
		
		# Create ULT button for this character
		var ult_btn = Button.new()
		ult_btn.name = "UltButton"
		ult_btn.text = "ULT"
		ult_btn.custom_minimum_size = Vector2(80, 35)
		ult_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		# Style the ult button
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.8, 0.2, 0.9)
		style.corner_radius_top_left = 17
		style.corner_radius_top_right = 17
		style.corner_radius_bottom_left = 17
		style.corner_radius_bottom_right = 17
		ult_btn.add_theme_stylebox_override("normal", style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(1.0, 0.4, 1.0)
		hover_style.corner_radius_top_left = 17
		hover_style.corner_radius_top_right = 17
		hover_style.corner_radius_bottom_left = 17
		hover_style.corner_radius_bottom_right = 17
		ult_btn.add_theme_stylebox_override("hover", hover_style)
		
		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = Color(0.4, 0.1, 0.4)
		disabled_style.corner_radius_top_left = 17
		disabled_style.corner_radius_top_right = 17
		disabled_style.corner_radius_bottom_left = 17
		disabled_style.corner_radius_bottom_right = 17
		ult_btn.add_theme_stylebox_override("disabled", disabled_style)
		
		ult_btn.add_theme_color_override("font_color", Color.WHITE)
		ult_btn.add_theme_font_size_override("font_size", 14)
		
		# Connect with character index
		ult_btn.pressed.connect(_on_ult_pressed.bind(i))
		
		portrait_container.add_child(ult_btn)
		ult_buttons.append(ult_btn)
		portrait_containers.append(portrait_container)
		
		# Add to portraits container
		char_portraits.add_child(portrait_container)
	
	print("Created ", ult_buttons.size(), " ult buttons for ", GameManager.player_party.size(), " party members")

func _on_ult_pressed(char_index: int):
	# Set the character who owns this ult button
	current_character = GameManager.player_party[char_index]
	current_skill = current_character.ultimate as SkillData
	print(current_character.character_name, " uses ULTIMATE!")
	show_card_panel()

func _on_affix_pressed(affix_type: String):
	current_affix_filter = affix_type
	print("Affix filter: ", affix_type)
	
	prefix_btn.modulate = Color(1, 1, 1)
	suffix_btn.modulate = Color(1, 1, 1)
	connector_btn.modulate = Color(1, 1, 1)
	other_btn.modulate = Color(1, 1, 1)
	
	match affix_type:
		"prefix": prefix_btn.modulate = Color(1.5, 1.5, 0.5)
		"suffix": suffix_btn.modulate = Color(1.5, 1.5, 0.5)
		"connector": connector_btn.modulate = Color(1.5, 1.5, 0.5)
		"other": other_btn.modulate = Color(1.5, 1.5, 0.5)

func make_circular_button(btn: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.corner_radius_top_left = 999
	hover_style.corner_radius_top_right = 999
	hover_style.corner_radius_bottom_left = 999
	hover_style.corner_radius_bottom_right = 999
	btn.add_theme_stylebox_override("hover", hover_style)

func setup_enemies():
	if GameManager.active_enemy_data:
		var enemy_instance = {
			"data": GameManager.active_enemy_data,
			"current_hp": GameManager.active_enemy_data.get_actual_hp(),
			"current_shield_hp": GameManager.active_enemy_data.get_actual_shield_hp(),
			"is_shield_active": GameManager.active_enemy_data.is_shield_active
		}
		enemies.append(enemy_instance)
		print("Enemy setup: ", GameManager.active_enemy_data.enemy_name)
		print("Enemy HP: ", enemy_instance.current_hp)

func build_turn_queue():
	turn_queue.clear()
	
	for char in GameManager.player_party:
		turn_queue.append({
			"type": "player",
			"data": char,
			"speed": char.speed
		})
	
	for enemy in enemies:
		turn_queue.append({
			"type": "enemy",
			"data": enemy,
			"speed": enemy.data.speed
		})
	
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)
	
	print("Turn order:")
	for t in turn_queue:
		print(" - ", t.data.character_name if t.type == "player" else t.data.data.enemy_name, " (Speed: ", t.speed, ")")

func draw_hand():
	var all_cards = []
	for f in DirAccess.get_files_at("res://Resources/Cards/"):
		if f.ends_with(".tres"):
			all_cards.append(load("res://Resources/Cards/" + f))
	
	var verbs = all_cards.filter(func(c): return c.card_type == "Action")
	var nouns = all_cards.filter(func(c): return c.card_type == "Noun")
	verbs.shuffle()
	nouns.shuffle()
	
	var has_verb = hand.any(func(c): return c.card_type == "Action")
	var has_noun = hand.any(func(c): return c.card_type == "Noun")
	
	if not has_verb and verbs.size() > 0:
		hand.append(verbs[0])
	if not has_noun and nouns.size() > 0:
		hand.append(nouns[0])
	
	all_cards.shuffle()
	for card in all_cards:
		if hand.size() >= 7:
			break
		if not hand.has(card):
			hand.append(card)
	
	print("Hand size: ", hand.size())
	update_card_display()

func start_battle():
	print("Battle started!")
	current_turn_index = 0
	process_next_turn()

func process_next_turn():
	if current_turn_index >= turn_queue.size():
		current_turn_index = 0
	
	var current = turn_queue[current_turn_index]
	update_turn_order_ui()
	
	if current.type == "player":
		current_character = current.data
		is_player_turn = true
		print("Player turn: ", current_character.character_name)
		show_skill_buttons()
	else:
		is_player_turn = false
		print("Enemy turn: ", current.data.data.enemy_name)
		await enemy_turn(current.data)

func show_skill_buttons():
	skill_buttons.visible = true
	card_panel.visible = false
	sentence_bar.visible = false
	
	# FIX: Check if skills exist before accessing properties
	var basic_data = current_character.basic_attack
	var skill_data = current_character.skill
	
	if basic_data == null or skill_data == null:
		push_error("Character " + current_character.character_name + " is missing basic_attack or skill!")
		# Set defaults to prevent crash
		basic_btn.text = "Basic\n(+1 SP)"
		skill_btn.text = "Skill\n(-2 SP)"
		skill_btn.disabled = current_sp < 2
		return
	
	basic_btn.text = "Basic\n(+" + str(basic_data.sp_gain) + " SP)"
	skill_btn.text = "Skill\n(-" + str(skill_data.sp_cost) + " SP)"
	skill_btn.disabled = current_sp < skill_data.sp_cost
	
	# Update ult buttons - only enable for current turn character
	for i in range(ult_buttons.size()):
		var ult_btn = ult_buttons[i]
		var char_data = GameManager.player_party[i]
		var ult_data = char_data.ultimate as SkillData
		var ult_cost = ult_data.sp_cost if ult_data else 999
		
		var is_current_char = (char_data == current_character)
		var has_enough_sp = current_sp >= ult_cost
		
		ult_btn.disabled = not (is_current_char and has_enough_sp)
		
		if is_current_char and has_enough_sp:
			ult_btn.modulate = Color(1, 1, 1)
		else:
			ult_btn.modulate = Color(0.5, 0.5, 0.5)
		
		# Highlight current character portrait
		if i < portrait_containers.size():
			if is_current_char:
				portrait_containers[i].modulate = Color(1.2, 1.2, 1.2)
			else:
				portrait_containers[i].modulate = Color(1, 1, 1)

func _on_basic_pressed():
	if current_character.basic_attack == null:
		push_error("No basic_attack skill for " + current_character.character_name)
		return
	current_skill = current_character.basic_attack as SkillData
	show_card_panel()

func _on_skill_pressed():
	if current_character.skill == null:
		push_error("No skill for " + current_character.character_name)
		return
	
	var skill_data = current_character.skill as SkillData
	if current_sp < skill_data.sp_cost:
		print("Not enough SP!")
		return
	current_skill = skill_data
	show_card_panel()

func show_card_panel():
	skill_buttons.visible = false
	card_panel.visible = true
	sentence_bar.visible = true
	sentence.clear()
	update_sentence_display()
	update_card_display()

const CARD_COLORS = {
	"Action": Color(0.85, 0.35, 0.28),
	"Noun": Color(0.2, 0.5, 0.85),
	"Number": Color(0.2, 0.75, 0.4),
	"Adjective": Color(0.75, 0.5, 0.85)
}

func update_card_display():
	for child in card_grid.get_children():
		child.queue_free()
	
	for i in range(hand.size()):
		var card = hand[i]
		var card_container = PanelContainer.new()
		card_container.custom_minimum_size = Vector2(150, 180)
		
		var style = StyleBoxFlat.new()
		var base_color = CARD_COLORS.get(card.card_type, Color(0.5, 0.5, 0.5))
		if sentence.has(card):
			style.bg_color = base_color.darkened(0.4)
		else:
			style.bg_color = base_color
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		card_container.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var type_lbl = Label.new()
		type_lbl.text = card.card_type
		type_lbl.add_theme_font_size_override("font_size", 10)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.add_theme_color_override("font_color", Color.WHITE)
		
		var word_lbl = Label.new()
		word_lbl.text = card.kapampangan_text
		word_lbl.add_theme_font_size_override("font_size", 18)
		word_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word_lbl.add_theme_color_override("font_color", Color.WHITE)
		word_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		var hint_lbl = Label.new()
		hint_lbl.text = card.english_hint
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		
		var cat_lbl = Label.new()
		cat_lbl.text = "[" + card.category + "]"
		cat_lbl.add_theme_font_size_override("font_size", 10)
		cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cat_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		
		vbox.add_child(type_lbl)
		vbox.add_child(word_lbl)
		vbox.add_child(hint_lbl)
		vbox.add_child(cat_lbl)
		card_container.add_child(vbox)
		
		var btn = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(_on_card_pressed.bind(i))
		card_container.add_child(btn)
		
		card_grid.add_child(card_container)

func _on_card_pressed(index: int):
	var card = hand[index]
	
	if sentence.has(card):
		sentence.erase(card)
	else:
		sentence.append(card)
	
	update_card_display()
	update_sentence_display()

func update_sentence_display():
	for child in sentence_container.get_children():
		child.queue_free()
	
	if sentence.size() == 0:
		var placeholder = Label.new()
		placeholder.text = "Select cards to build your sentence..."
		placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		sentence_container.add_child(placeholder)
		return
	
	for card in sentence:
		var pill = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = CARD_COLORS.get(card.card_type, Color(0.5, 0.5, 0.5))
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.corner_radius_bottom_left = 20
		style.corner_radius_bottom_right = 20
		pill.add_theme_stylebox_override("panel", style)
		
		var lbl = Label.new()
		lbl.text = card.kapampangan_text
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 16)
		pill.add_child(lbl)
		
		var btn = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(func(): 
			sentence.erase(card)
			update_card_display()
			update_sentence_display()
		)
		pill.add_child(btn)
		sentence_container.add_child(pill)

func _on_submit_pressed():
	if sentence.size() == 0:
		print("No cards selected!")
		return
	
	var is_valid = check_grammar()
	print("Sentence valid: ", is_valid)
	
	if is_valid:
		var damage = calculate_damage()
		deal_damage(damage)
		
		if current_skill.skill_type == "Basic":
			current_sp = min(current_sp + current_skill.sp_gain, max_sp)
		elif current_skill.skill_type == "Skill":
			current_sp -= current_skill.sp_cost
		elif current_skill.skill_type == "Ultimate":
			current_sp -= current_skill.sp_cost
		
		print("SP: ", current_sp, "/", max_sp)
	else:
		print("Invalid sentence! No damage dealt.")
	
	for card in sentence:
		hand.erase(card)
	sentence.clear()
	
	draw_hand()
	
	current_turn_index += 1
	await get_tree().create_timer(1.0).timeout
	process_next_turn()

func check_grammar() -> bool:
	var has_action = false
	var has_noun = false
	
	for card in sentence:
		if card.card_type == "Action":
			has_action = true
		if card.card_type == "Noun":
			has_noun = true
	
	var min_words = 2
	if current_skill.skill_type == "Skill":
		min_words = 3
	elif current_skill.skill_type == "Ultimate":
		min_words = 4
	
	return has_action and has_noun and sentence.size() >= min_words

func calculate_damage() -> int:
	var base_attack = current_character.get_actual_attack()
	var multiplier = current_skill.get_actual_multiplier()
	var damage = int(base_attack * multiplier)
	
	var talent = current_character.talent as SkillData
	if talent:
		for card in sentence:
			if card.category == talent.trigger_card_category:
				damage = int(damage * (1.0 + talent.trigger_value))
				print("Talent triggered! Damage boosted!")
				break
	
	if randf() < current_character.crit_rate:
		damage = int(damage * current_character.crit_damage)
		print("CRITICAL HIT!")
	
	print("Damage calculated: ", damage)
	return damage

func deal_damage(damage: int):
	if enemies.size() == 0:
		return
	
	var target = enemies[0]
	
	if target.is_shield_active:
		if current_skill.element == target.data.shield_element:
			target.current_shield_hp -= damage
			if target.current_shield_hp <= 0:
				target.is_shield_active = false
				print("SHIELD BROKEN!")
				damage = abs(target.current_shield_hp)
			else:
				print("Shield hit! Shield HP: ", target.current_shield_hp)
				damage = 0
		else:
			print("Wrong element! Can't break shield.")
			damage = int(damage * 0.1)
	
	target.current_hp -= damage
	total_damage_dealt += damage
	total_damage_label.text = "Total: " + str(total_damage_dealt)
	
	print("Enemy HP: ", target.current_hp, "/", target.data.get_actual_hp())
	
	if target.current_hp <= 0:
		print("Enemy defeated!")
		enemies.erase(target)
		check_battle_end()

func enemy_turn(enemy_instance: Dictionary):
	print("Enemy attacks!")
	await get_tree().create_timer(1.5).timeout
	
	if GameManager.player_party.size() > 0:
		var target_index = randi() % GameManager.player_party.size()
		var target = GameManager.player_party[target_index]
		var damage = enemy_instance.data.base_attack
		print("Enemy deals ", damage, " to ", target.character_name)
	
	current_turn_index += 1
	process_next_turn()

func check_battle_end():
	if enemies.size() == 0:
		print("Victory!")
		await get_tree().create_timer(2.0).timeout
		SupabaseManager.add_pulls(1)
		get_tree().change_scene_to_file("res://Scenes/Zone1.tscn")
	elif GameManager.player_party.size() == 0:
		print("Defeat!")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://Scenes/HubTown.tscn")

func update_turn_order_ui():
	for child in turn_order_ui.get_children():
		child.queue_free()
	
	for i in range(min(5, turn_queue.size())):
		var idx = (current_turn_index + i) % turn_queue.size()
		var turn = turn_queue[idx]
		var lbl = Label.new()
		if turn.type == "player":
			lbl.text = turn.data.character_name
		else:
			lbl.text = turn.data.data.enemy_name
		if i == 0:
			lbl.add_theme_color_override("font_color", Color.YELLOW)
		turn_order_ui.add_child(lbl)

func setup_battle_sprites():
	# FIX: Only remove character sprites, preserve the background mesh
	for child in $Background.get_children():
		# Only delete nodes that are character sprites, not the mesh
		if child.name.begins_with("player_") or child.name.begins_with("enemy_") or child.name.begins_with("Placeholder_") or child.name.begins_with("Enemy_"):
			child.queue_free()
	
	# Spawn player characters
	for i in range(GameManager.player_party.size()):
		var char_data = GameManager.player_party[i]
		spawn_character(char_data, i, "player")
	
	# Spawn enemy
	if GameManager.active_enemy_data:
		spawn_enemy()

func spawn_character(data: CharacterData, index: int, side: String):
	# Try loading by character name (lowercase)
	var scene_name = data.character_name.to_lower()
	var scene_path = "res://Characters/" + scene_name + ".tscn"
	var scene = load(scene_path)
	
	if scene == null:
		print("No scene found for: ", scene_name, " - using placeholder")
		create_placeholder(data, index, side)
		return
	
	var instance = scene.instantiate()
	if instance.has_method("setup"):
		instance.setup(data, side)
	
	# FIX: Make characters bigger
	instance.scale = Vector3(2.5, 2.5, 2.5)
	
	if side == "player":
		instance.position = Vector3(-4 + (index * 2.5), 0, 0)
	else:
		instance.position = Vector3(4, 0, 0)
	
	instance.name = side + "_" + data.character_name
	$Background.add_child(instance)

func spawn_enemy():
	# Enemies use placeholders for now
	create_enemy_placeholder()

func create_enemy_placeholder():
	if not GameManager.active_enemy_data:
		return
	var sprite = AnimatedSprite3D.new()
	sprite.name = "Enemy_Placeholder"
	sprite.position = Vector3(3, 0, 0)
	
	# Create colored placeholder
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2))
	var tex = ImageTexture.create_from_image(img)
	
	var frames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", tex)
	sprite.sprite_frames = frames
	sprite.animation = "idle"
	
	# FIX: Make enemy bigger
	sprite.scale = Vector3(3, 3, 1)
	
	$Background.add_child(sprite)

func create_placeholder(data: CharacterData, index: int, side: String):
	var sprite = AnimatedSprite3D.new()
	sprite.name = "Placeholder_" + data.character_name
	
	# Use splash art if available
	if data.splash_art:
		var frames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", data.splash_art)
		sprite.sprite_frames = frames
		sprite.animation = "idle"
		sprite.pixel_size = 0.01
	else:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		# Different color per element
		match data.element:
			"Water": img.fill(Color(0.2, 0.4, 0.9))
			"Fire": img.fill(Color(0.9, 0.3, 0.1))
			"Earth": img.fill(Color(0.6, 0.4, 0.2))
			"Wind": img.fill(Color(0.2, 0.8, 0.4))
			_: img.fill(Color(0.5, 0.5, 0.5))
		var tex = ImageTexture.create_from_image(img)
		var frames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", tex)
		sprite.sprite_frames = frames
		sprite.animation = "idle"
	
	if side == "player":
		sprite.position = Vector3(-4 + (index * 2.5), 0, 0)
	else:
		sprite.position = Vector3(4, 0, 0)
	
	# FIX: Make placeholder bigger
	sprite.scale = Vector3(3, 3, 1)
	
	$Background.add_child(sprite)
