extends Node3D

# UI References
@onready var turn_order = $BattleUI/TopBar/TurnOrder
@onready var total_damage = $BattleUI/TopBar/TotalDamage
@onready var char_portraits = $BattleUI/BottomBar/CharPortraits
@onready var skill_buttons = $BattleUI/BottomBar/SkillButtons
@onready var basic_btn = $BattleUI/BottomBar/SkillButtons/BasicButton
@onready var skill_btn = $BattleUI/BottomBar/SkillButtons/SkillButton
@onready var ult_btn = $BattleUI/BottomBar/SkillButtons/UltButton
@onready var card_panel = $BattleUI/CardPanel
@onready var camera = $Camera3D

# Battle state
var current_character: CharacterData = null
var current_skill: SkillData = null
var hand: Array = []
var sentence: Array = []
var total_damage_dealt: int = 0
var current_enemy: EnemyData = null

func _ready():
	# Fade in when battle loads
	var transition = get_tree().get_first_node_in_group("transition")
	if transition:
		transition.fade_in()
	
	current_enemy = GameManager.active_enemy_data
	card_panel.visible = false
	basic_btn.pressed.connect(_on_basic_pressed)
	skill_btn.pressed.connect(_on_skill_pressed)
	ult_btn.pressed.connect(_on_ult_pressed)
	start_battle()

func start_battle():
	print("Battle started!")
	print("Enemy: ", current_enemy)
	# Draw initial hand
	draw_hand()
	# Set first character turn
	set_character_turn(0)

func draw_hand():
	hand.clear()
	# Load all cards
	var all_cards = []
	for f in DirAccess.get_files_at("res://Resources/Cards/"):
		if f.ends_with(".tres"):
			all_cards.append(load("res://Resources/Cards/" + f))
	
	# Guarantee at least 1 verb and 1 noun
	var verbs = all_cards.filter(func(c): return c.card_type == "Action")
	var nouns = all_cards.filter(func(c): return c.card_type == "Noun")
	
	verbs.shuffle()
	nouns.shuffle()
	
	hand.append(verbs[0])
	hand.append(nouns[0])
	
	# Fill remaining 5 slots randomly
	all_cards.shuffle()
	var count = 0
	for card in all_cards:
		if not hand.has(card) and count < 5:
			hand.append(card)
			count += 1
	
	print("Hand drawn: ", hand.size(), " cards")

func set_character_turn(index: int):
	if GameManager.player_party.size() == 0:
		print("No party set!")
		return
	current_character = GameManager.player_party[index]
	print("Current turn: ", current_character.character_name)

func _on_basic_pressed():
	current_skill = current_character.basic_attack as SkillData
	show_card_panel()

func _on_skill_pressed():
	current_skill = current_character.skill as SkillData
	show_card_panel()

func _on_ult_pressed():
	current_skill = current_character.ultimate as SkillData
	show_card_panel()

func show_card_panel():
	card_panel.visible = true
	skill_buttons.visible = false
	print("Card panel shown!")

func hide_card_panel():
	card_panel.visible = false
	skill_buttons.visible = true
