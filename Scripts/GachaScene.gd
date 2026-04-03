extends Control
# ─────────────────────────────────────────────
#  GachaScene.gd
#  Attach to a full-screen Control node
#  Scene path: res://Scenes/GachaScene.tscn
# ─────────────────────────────────────────────

# ── State ─────────────────────────────────────
var _pull_results:    Array  = []
var _current_reveal:  int    = 0
var _skip_all:        bool   = false
var _animating:       bool   = false

# ── Colors per rarity ─────────────────────────
const COLOR_5STAR = Color(1.0,  0.75, 0.10)
const COLOR_4STAR = Color(0.70, 0.30, 1.00)
const COLOR_3STAR = Color(0.30, 0.60, 1.00)
const COLOR_BG    = Color(0.04, 0.04, 0.10)

# ─────────────────────────────────────────────
func _ready():
	GachaManager.load_pity_from_profile()
	_build_ui()

# ─────────────────────────────────────────────
#  UI construction
# ─────────────────────────────────────────────
func _build_ui():
	# Full-screen dark background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# ── Top bar ───────────────────────────────
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top_bar.offset_bottom = 60.0
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	# Back button
	var back_btn = _make_btn("← Back", Color(0.3, 0.3, 0.4))
	back_btn.custom_minimum_size = Vector2(100, 44)
	back_btn.pressed.connect(_on_back)
	top_bar.add_child(back_btn)

	# Pulls counter
	var pulls_lbl = Label.new()
	pulls_lbl.name = "PullsLabel"
	pulls_lbl.add_theme_font_size_override("font_size", 18)
	pulls_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	pulls_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(pulls_lbl)

	# Pity info
	var pity_lbl = Label.new()
	pity_lbl.name = "PityLabel"
	pity_lbl.add_theme_font_size_override("font_size", 13)
	pity_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	pity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(pity_lbl)

	# Skip all button (hidden during idle)
	var skip_all_btn = _make_btn("Skip All", Color(0.5, 0.5, 0.6))
	skip_all_btn.name = "SkipAllBtn"
	skip_all_btn.custom_minimum_size = Vector2(90, 44)
	skip_all_btn.visible = false
	skip_all_btn.pressed.connect(_on_skip_all)
	top_bar.add_child(skip_all_btn)

	# ── Banner display ────────────────────────
	var banner_area = VBoxContainer.new()
	banner_area.name = "BannerArea"
	banner_area.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	banner_area.offset_top    = 70.0
	banner_area.offset_bottom = -160.0
	banner_area.alignment     = BoxContainer.ALIGNMENT_CENTER
	add_child(banner_area)

	# Banner title
	var title = Label.new()
	title.name = "BannerTitle"
	title.text = "GACHA"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	banner_area.add_child(title)

	# Pity progress bars
	var pity_bars = HBoxContainer.new()
	pity_bars.name = "PityBars"
	pity_bars.alignment = BoxContainer.ALIGNMENT_CENTER
	pity_bars.add_theme_constant_override("separation", 20)
	banner_area.add_child(pity_bars)

	var pity5_vbox = _make_pity_bar("5★ Pity", "Pity5Bar", COLOR_5STAR, GachaManager.HARD_PITY_5STAR)
	var pity4_vbox = _make_pity_bar("4★ Pity", "Pity4Bar", COLOR_4STAR, GachaManager.HARD_PITY_4STAR)
	pity_bars.add_child(pity5_vbox)
	pity_bars.add_child(pity4_vbox)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	banner_area.add_child(spacer)

	# ── Reveal area (cinematic panel) ─────────
	var reveal_panel = PanelContainer.new()
	reveal_panel.name = "RevealPanel"
	reveal_panel.visible = false
	reveal_panel.custom_minimum_size = Vector2(400, 300)
	reveal_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_panel(reveal_panel, Color(0.06, 0.06, 0.15, 0.98))
	banner_area.add_child(reveal_panel)

	var reveal_vbox = VBoxContainer.new()
	reveal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reveal_vbox.add_theme_constant_override("separation", 12)
	reveal_panel.add_child(reveal_vbox)

	# Star rarity label
	var star_lbl = Label.new()
	star_lbl.name = "StarLabel"
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 32)
	reveal_vbox.add_child(star_lbl)

	# Art display
	var art_rect = TextureRect.new()
	art_rect.name = "RevealArt"
	art_rect.custom_minimum_size = Vector2(180, 180)
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reveal_vbox.add_child(art_rect)

	# Name label
	var name_lbl = Label.new()
	name_lbl.name = "RevealName"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	reveal_vbox.add_child(name_lbl)

	# Sub label (job / card type)
	var sub_lbl = Label.new()
	sub_lbl.name = "RevealSub"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	reveal_vbox.add_child(sub_lbl)

	# NEW badge
	var new_lbl = Label.new()
	new_lbl.name = "NewBadge"
	new_lbl.text = "✦ NEW ✦"
	new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_lbl.add_theme_font_size_override("font_size", 16)
	new_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	new_lbl.visible = false
	reveal_vbox.add_child(new_lbl)

	# Tap to continue hint
	var tap_lbl = Label.new()
	tap_lbl.name = "TapHint"
	tap_lbl.text = "Tap anywhere to continue"
	tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_lbl.add_theme_font_size_override("font_size", 12)
	tap_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	reveal_vbox.add_child(tap_lbl)

	# ── Grid results (shown after all revealed) ──
	var grid_scroll = ScrollContainer.new()
	grid_scroll.name = "GridScroll"
	grid_scroll.visible = false
	grid_scroll.custom_minimum_size = Vector2(600, 260)
	grid_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner_area.add_child(grid_scroll)

	var grid = GridContainer.new()
	grid.name = "ResultGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(grid)

	# ── Bottom buttons ────────────────────────
	var bottom = HBoxContainer.new()
	bottom.name = "BottomBar"
	bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bottom.offset_top = -140.0
	bottom.alignment  = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	add_child(bottom)

	var pull1_btn = _make_pull_btn("Single Pull\n(1 Pull)", "Pull1Btn")
	var pull10_btn = _make_pull_btn("10x Pull\n(10 Pulls)", "Pull10Btn")
	pull1_btn.pressed.connect(_on_pull_single)
	pull10_btn.pressed.connect(_on_pull_ten)
	bottom.add_child(pull1_btn)
	bottom.add_child(pull10_btn)

	_refresh_ui()

# ─────────────────────────────────────────────
#  Pity bar helper
# ─────────────────────────────────────────────
func _make_pity_bar(label_text: String, bar_name: String, color: Color, max_val: int) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200, 0)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var bar = ProgressBar.new()
	bar.name = bar_name
	bar.max_value = float(max_val)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 12)
	_style_progress_bar(bar, color)
	vbox.add_child(bar)

	var count_lbl = Label.new()
	count_lbl.name = bar_name + "Label"
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_lbl)

	return vbox

func _style_progress_bar(bar: ProgressBar, color: Color):
	var sf = StyleBoxFlat.new()
	sf.bg_color = color
	for c in ["top_left","top_right","bottom_left","bottom_right"]: sf.set("corner_radius_"+c, 6)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.2)
	for c in ["top_left","top_right","bottom_left","bottom_right"]: sb.set("corner_radius_"+c, 6)
	bar.add_theme_stylebox_override("fill", sf)
	bar.add_theme_stylebox_override("background", sb)

# ─────────────────────────────────────────────
#  UI refresh
# ─────────────────────────────────────────────
func _refresh_ui():
	# Pulls label
	var pulls = int(GameManager.player_profile.get("pulls", 0))
	var pulls_lbl = get_node_or_null("TopBar/PullsLabel")
	if pulls_lbl: pulls_lbl.text = "✦ " + str(pulls) + " Pulls"

	# Pity label
	var pity_lbl = get_node_or_null("TopBar/PityLabel")
	if pity_lbl:
		pity_lbl.text = "5★ in " + str(GachaManager.HARD_PITY_5STAR - GachaManager.pity_count) + " guaranteed"

	# Pity bars
	var p5 = get_node_or_null("BannerArea/PityBars/Pity5Bar")
	var p5l = get_node_or_null("BannerArea/PityBars/Pity5BarLabel")
	if p5:
		p5.value = float(GachaManager.pity_count)
		if p5l: p5l.text = str(GachaManager.pity_count) + "/" + str(GachaManager.HARD_PITY_5STAR)

	var p4 = get_node_or_null("BannerArea/PityBars/Pity4Bar")
	var p4l = get_node_or_null("BannerArea/PityBars/Pity4BarLabel")
	if p4:
		p4.value = float(GachaManager.pity_count_4star)
		if p4l: p4l.text = str(GachaManager.pity_count_4star) + "/" + str(GachaManager.HARD_PITY_4STAR)

	# Guaranteed badge
	var banner_title = get_node_or_null("BannerArea/BannerTitle")
	if banner_title:
		if GachaManager.guaranteed_featured:
			banner_title.text = "GACHA  ✦ GUARANTEED FEATURED ✦"
		else:
			banner_title.text = "GACHA"

	# Button enable state
	var p1 = get_node_or_null("BottomBar/Pull1Btn")
	var p10 = get_node_or_null("BottomBar/Pull10Btn")
	if p1:  p1.disabled  = pulls < 1
	if p10: p10.disabled = pulls < 10

# ─────────────────────────────────────────────
#  Pull handlers
# ─────────────────────────────────────────────
func _on_pull_single():
	if not GachaManager.can_pull(1): return
	GachaManager.deduct_pulls(1)
	_refresh_ui()
	var results = await GachaManager.do_single_pull()
	_start_reveal(results)

func _on_pull_ten():
	if not GachaManager.can_pull(10): return
	GachaManager.deduct_pulls(10)
	_refresh_ui()
	var results = await GachaManager.do_ten_pull()
	_start_reveal(results)

# ─────────────────────────────────────────────
#  Reveal flow
# ─────────────────────────────────────────────
func _start_reveal(results: Array):
	_pull_results    = results
	_current_reveal  = 0
	_skip_all        = false
	_animating       = true

	# Hide grid, show reveal panel
	var grid_scroll   = get_node_or_null("BannerArea/GridScroll")
	var reveal_panel  = get_node_or_null("BannerArea/RevealPanel")
	var skip_all_btn  = get_node_or_null("TopBar/SkipAllBtn")
	if grid_scroll:  grid_scroll.visible  = false
	if reveal_panel: reveal_panel.visible = true
	if skip_all_btn: skip_all_btn.visible = true

	# Disable pull buttons during reveal
	_set_pull_buttons_enabled(false)

	_reveal_next()

func _reveal_next():
	if _current_reveal >= _pull_results.size():
		_finish_reveal()
		return

	var result = _pull_results[_current_reveal]
	_show_reveal(result)
	_current_reveal += 1

func _show_reveal(result: Dictionary):
	var rarity   = result.get("rarity", 3)
	var color    = _rarity_color(rarity)
	var bg       = get_node_or_null("Background")
	var panel    = get_node_or_null("BannerArea/RevealPanel")
	var star_lbl = get_node_or_null("BannerArea/RevealPanel/VBoxContainer/StarLabel")
	var art      = get_node_or_null("BannerArea/RevealPanel/VBoxContainer/RevealArt")
	var name_lbl = get_node_or_null("BannerArea/RevealPanel/VBoxContainer/RevealName")
	var sub_lbl  = get_node_or_null("BannerArea/RevealPanel/VBoxContainer/RevealSub")
	var new_badge = get_node_or_null("BannerArea/RevealPanel/VBoxContainer/NewBadge")

	# Star text
	var stars = ""
	for i in range(rarity): stars += "★"
	if star_lbl:
		star_lbl.text = stars
		star_lbl.add_theme_color_override("font_color", color)

	# Fill content
	var data = result.get("data")
	if data is CharacterData:
		if art:      art.texture      = data.splash_art
		if name_lbl: name_lbl.text    = data.character_name
		if sub_lbl:  sub_lbl.text     = data.job + " · " + data.element
	elif data is GachaCard:
		if art:      art.texture      = data.card_art
		if name_lbl: name_lbl.text    = data.card_name_kap
		if sub_lbl:  sub_lbl.text     = data.card_name + " · " + str(rarity) + "★ Card"
	else:
		if art:      art.texture      = null
		if name_lbl: name_lbl.text    = str(rarity) + "★ Card"
		if sub_lbl:  sub_lbl.text     = ""

	if new_badge: new_badge.visible = result.get("is_new", false)

	# Flash animation
	if bg and not _skip_all:
		var tween = create_tween()
		tween.tween_property(bg, "color", color.darkened(0.7), 0.12)
		tween.tween_property(bg, "color", COLOR_BG, 0.35)

	if panel and not _skip_all:
		panel.modulate.a = 0.0
		var t2 = create_tween()
		t2.tween_property(panel, "modulate:a", 1.0, 0.25)

func _finish_reveal():
	_animating = false

	var reveal_panel = get_node_or_null("BannerArea/RevealPanel")
	var grid_scroll  = get_node_or_null("BannerArea/GridScroll")
	var skip_all_btn = get_node_or_null("TopBar/SkipAllBtn")
	if reveal_panel: reveal_panel.visible = false
	if grid_scroll:  grid_scroll.visible  = true
	if skip_all_btn: skip_all_btn.visible = false

	# Restore BG
	var bg = get_node_or_null("Background")
	if bg: bg.color = COLOR_BG

	_build_result_grid()
	_set_pull_buttons_enabled(true)
	_refresh_ui()

func _build_result_grid():
	var grid = get_node_or_null("BannerArea/GridScroll/ResultGrid")
	if not grid: return
	for child in grid.get_children(): child.queue_free()

	for result in _pull_results:
		var rarity = result.get("rarity", 3)
		var color  = _rarity_color(rarity)

		var card_cont = PanelContainer.new()
		card_cont.custom_minimum_size = Vector2(100, 130)
		_style_panel(card_cont, color.darkened(0.6))

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_cont.add_child(vbox)

		var art = TextureRect.new()
		art.custom_minimum_size = Vector2(70, 70)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var data = result.get("data")
		if data is CharacterData and data.splash_art: art.texture = data.splash_art
		elif data is GachaCard and data.card_art: art.texture = data.card_art
		vbox.add_child(art)

		var stars = ""
		for i in range(rarity): stars += "★"
		var star_lbl = Label.new()
		star_lbl.text = stars
		star_lbl.add_theme_font_size_override("font_size", 11)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.add_theme_color_override("font_color", color)
		vbox.add_child(star_lbl)

		var name_lbl = Label.new()
		var dname = ""
		if data is CharacterData: dname = data.character_name
		elif data is GachaCard:   dname = data.card_name_kap
		name_lbl.text = dname
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(name_lbl)

		grid.add_child(card_cont)

# ─────────────────────────────────────────────
#  Input — tap to advance reveal
# ─────────────────────────────────────────────
func _input(event: InputEvent):
	if not _animating: return
	if event is InputEventMouseButton and event.pressed:
		if _current_reveal < _pull_results.size():
			_reveal_next()
		elif _animating:
			_finish_reveal()

func _on_skip_all():
	_skip_all = true
	_current_reveal = _pull_results.size()
	_finish_reveal()

# ─────────────────────────────────────────────
#  Navigation
# ─────────────────────────────────────────────
func _on_back():
	# Return to wherever we came from
	var prev = GameManager.get_meta("gacha_return_scene",
		"res://Scenes/HubTown.tscn")
	get_tree().change_scene_to_file(prev)

# ─────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────
func _rarity_color(rarity: int) -> Color:
	match rarity:
		5: return COLOR_5STAR
		4: return COLOR_4STAR
		_: return COLOR_3STAR

func _set_pull_buttons_enabled(enabled: bool):
	var p1  = get_node_or_null("BottomBar/Pull1Btn")
	var p10 = get_node_or_null("BottomBar/Pull10Btn")
	if p1:  p1.disabled  = not enabled
	if p10: p10.disabled = not enabled

func _make_btn(label: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	var s = StyleBoxFlat.new()
	s.bg_color = color
	for c in ["top_left","top_right","bottom_left","bottom_right"]: s.set("corner_radius_"+c, 10)
	btn.add_theme_stylebox_override("normal", s)
	var h = StyleBoxFlat.new()
	h.bg_color = color.lightened(0.2)
	for c in ["top_left","top_right","bottom_left","bottom_right"]: h.set("corner_radius_"+c, 10)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

func _make_pull_btn(label: String, node_name: String) -> Button:
	var btn = _make_btn(label, Color(0.6, 0.4, 0.1))
	btn.name = node_name
	btn.custom_minimum_size = Vector2(160, 80)
	btn.add_theme_font_size_override("font_size", 16)
	# Gold border
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.5, 0.35, 0.05)
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_color        = COLOR_5STAR
	for c in ["top_left","top_right","bottom_left","bottom_right"]: s.set("corner_radius_"+c, 12)
	btn.add_theme_stylebox_override("normal", s)
	return btn

func _style_panel(panel: PanelContainer, color: Color):
	var s = StyleBoxFlat.new()
	s.bg_color = color
	for c in ["top_left","top_right","bottom_left","bottom_right"]: s.set("corner_radius_"+c, 14)
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color        = Color(1,1,1,0.15)
	panel.add_theme_stylebox_override("panel", s)
