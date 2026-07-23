class_name GachaScene
extends Control

# ═════════════════════════════════════════════════════════════════════════════
#  GachaScene.gd
#  Attach to:  res://Scenes/GachaScene.tscn  (root Control node)
# ═════════════════════════════════════════════════════════════════════════════

const GachaResultData := preload("res://Scripts/GachaResultData.gd")

# ── Rarity palette ────────────────────────────────────────────────────────────
const C5  := Color(1.00, 0.82, 0.12)   # gold
const C4  := Color(0.72, 0.32, 1.00)   # violet
const C3  := Color(0.30, 0.62, 1.00)   # blue
const CBG := Color(0.04, 0.04, 0.10)   # scene background

# ── Reveal timing ─────────────────────────────────────────────────────────────
const FLASH_IN    := 0.10
const FLASH_OUT   := 0.45
const PANEL_FADE    := 0.22
const PANEL_SCALE_T := 0.18
const RAY_FADE_IN   := 0.18
const RAY_HOLD      := 0.55
const RAY_FADE_OUT  := 0.40
const GRID_STAGGER  := 0.06

# ── Node references ──────────────────────────────────────────────────────────
@onready var background:       ColorRect     = $Background
@onready var star_particles:   CPUParticles2D = $StarParticles
@onready var rarity_flash:     ColorRect     = $RarityFlash
@onready var ray_burst:        Control       = $RayBurst

@onready var top_bar:          HBoxContainer = $TopBar
@onready var back_btn:          Button        = $TopBar/BackBtn
@onready var pulls_label:      Label         = $TopBar/PullsLabel
@onready var pity_label:       Label         = $TopBar/PityLabel
@onready var skip_all_btn:      Button        = $TopBar/SkipAllBtn

@onready var pity5_bar:        ProgressBar   = $CenterContent/PityRow/Pity5Box/Pity5Bar
@onready var pity5_label:      Label         = $CenterContent/PityRow/Pity5Box/Pity5Label
@onready var pity4_bar:        ProgressBar   = $CenterContent/PityRow/Pity4Box/Pity4Bar
@onready var pity4_label:      Label         = $CenterContent/PityRow/Pity4Box/Pity4Label
@onready var guaranteed_badge: Label         = $CenterContent/GuaranteedBadge

@onready var reveal_panel:     PanelContainer = $CenterContent/RevealPanel
@onready var star_label:       Label          = $CenterContent/RevealPanel/RevealVBox/StarLabel
@onready var reveal_art:       TextureRect    = $CenterContent/RevealPanel/RevealVBox/RevealArt
@onready var reveal_name:      Label          = $CenterContent/RevealPanel/RevealVBox/RevealName
@onready var reveal_sub:       Label          = $CenterContent/RevealPanel/RevealVBox/RevealSub
@onready var duplicate_badge: Label          = $CenterContent/RevealPanel/RevealVBox/DuplicateBadge
@onready var tap_hint:         Label          = $CenterContent/RevealPanel/RevealVBox/TapHint

@onready var grid_scroll:      ScrollContainer = $CenterContent/GridScroll
@onready var result_grid:      GridContainer   = $CenterContent/GridScroll/ResultGrid

@onready var pull1_btn:        Button = $BottomBar/Pull1Btn
@onready var pull10_btn:       Button = $BottomBar/Pull10Btn

# ── State ─────────────────────────────────────────────────────────────────────
var _results:      Array  = []
var _reveal_index:   int    = 0
var _skip_all:       bool   = false
var _animating:      bool   = false
var _awaiting_tap:   bool   = false

# ═════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_apply_theme()
	_connect_signals()
	_refresh_ui()
	_animate_intro()

func _input(event: InputEvent) -> void:
	if not _animating: return
	if event is InputEventMouseButton and event.pressed and _awaiting_tap:
		_on_tap_advance()

# ═════════════════════════════════════════════════════════════════════════════
#  THEME APPLICATION
# ═════════════════════════════════════════════════════════════════════════════
func _apply_theme() -> void:
	background.color = CBG

	_style_btn(back_btn,     Color(0.22, 0.22, 0.30))
	_style_btn(skip_all_btn, Color(0.40, 0.40, 0.50))

	_style_pull_btn(pull1_btn)
	_style_pull_btn(pull10_btn)

	_style_progress_bar(pity5_bar, C5)
	_style_progress_bar(pity4_bar, C4)

	($CenterContent/PityRow/Pity5Box/Pity5Title as Label)\
		.add_theme_color_override("font_color", C5)
	($CenterContent/PityRow/Pity4Box/Pity4Title as Label)\
		.add_theme_color_override("font_color", C4)

	pulls_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	pity_label.add_theme_color_override("font_color",  Color(0.70, 0.70, 0.90))
	guaranteed_badge.add_theme_color_override("font_color", C5)

	_style_panel(reveal_panel, Color(0.06, 0.06, 0.16, 0.97))

	reveal_name.add_theme_color_override("font_color", Color.WHITE)
	reveal_sub.add_theme_color_override("font_color",  Color(0.78, 0.78, 0.78))
	duplicate_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	tap_hint.add_theme_color_override("font_color",    Color(0.45, 0.45, 0.55))

	_build_ray_burst()

func _connect_signals() -> void:
	back_btn.pressed.connect(_on_back)
	skip_all_btn.pressed.connect(_on_skip_all)
	pull1_btn.pressed.connect(_on_pull_single)
	pull10_btn.pressed.connect(_on_pull_ten)

# ═════════════════════════════════════════════════════════════════════════════
#  UI REFRESH
# ═════════════════════════════════════════════════════════════════════════════
func _refresh_ui() -> void:
	var pulls: int = GachaManager.pulls if GachaManager != null else 0
	pulls_label.text = "✦ " + str(pulls) + " Pulls"

	var pity_cnt: int = GachaManager.pity_count if GachaManager != null else 0
	var hard_pity: int = GachaManager.HARD_PITY_5STAR if GachaManager != null else 90
	var to5: int = hard_pity - pity_cnt
	pity_label.text = "5★ guaranteed in " + str(to5)

	pity5_bar.value   = float(pity_cnt)
	pity5_label.text  = str(pity_cnt) + " / " + str(hard_pity)
	
	var pity4_cnt: int = GachaManager.pity_count_4star if GachaManager != null else 0
	var hard_pity4: int = GachaManager.HARD_PITY_4STAR if GachaManager != null else 10
	pity4_bar.value   = float(pity4_cnt)
	pity4_label.text  = str(pity4_cnt) + " / " + str(hard_pity4)

	guaranteed_badge.visible = GachaManager.guaranteed_featured if GachaManager != null else false

	# Respect animation state during UI refreshes
	_set_pull_buttons_enabled(not _animating)

# ═════════════════════════════════════════════════════════════════════════════
#  INTRO ANIMATION
# ═════════════════════════════════════════════════════════════════════════════
func _animate_intro() -> void:
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.50).set_ease(Tween.EASE_OUT)
	star_particles.modulate.a = 0.0
	t.parallel().tween_property(star_particles, "modulate:a", 1.0, 0.90)

# ═════════════════════════════════════════════════════════════════════════════
#  PULL HANDLERS
# ═════════════════════════════════════════════════════════════════════════════
func _on_pull_single() -> void:
	if _animating: return
	if GachaManager != null and not GachaManager.can_pull(1): return
	
	# Immediately lock out user inputs before any async work begins
	_animating = true
	_set_pull_buttons_enabled(false)

	if GachaManager != null:
		GachaManager.deduct_pulls(1)
	_refresh_ui()

	var results: Array = []
	if GachaManager != null:
		results = await GachaManager.do_single_pull_typed()
	
	# Standalone/Simulation Fallback if GachaManager returns empty results
	if results.is_empty():
		results = [_generate_mock_result()]
		
	_start_reveal(results)

func _on_pull_ten() -> void:
	if _animating: return
	if GachaManager != null and not GachaManager.can_pull(10): return
	
	# Immediately lock out user inputs before any async work begins
	_animating = true
	_set_pull_buttons_enabled(false)

	if GachaManager != null:
		GachaManager.deduct_pulls(10)
	_refresh_ui()

	var results: Array = []
	if GachaManager != null:
		results = await GachaManager.do_ten_pull_typed()
	
	# Standalone/Simulation Fallback if GachaManager returns empty results
	if results.is_empty():
		results = []
		for i in range(10):
			results.append(_generate_mock_result())
			
	_start_reveal(results)

# ── Mock result generator for testing ─────────────────────────────────────────
func _generate_mock_result() -> GachaResultData:
	var res := GachaResultData.new()
	var roll := randf()
	if roll < 0.08:
		res.rarity = 5
		res.display_name = "Sample 5★ Character"
	elif roll < 0.25:
		res.rarity = 4
		res.display_name = "Sample 4★ Item"
	else:
		res.rarity = 3
		res.display_name = "Sample 3★ Weapon"
		
	res.is_new = (randf() > 0.5)
	return res

# ═════════════════════════════════════════════════════════════════════════════
#  REVEAL FLOW
# ═════════════════════════════════════════════════════════════════════════════
func _start_reveal(results: Array) -> void:
	_results       = results
	_reveal_index  = 0
	_skip_all      = false
	_animating     = true
	_awaiting_tap  = false

	grid_scroll.visible  = false
	reveal_panel.visible = true
	skip_all_btn.visible = true
	_set_pull_buttons_enabled(false)

	_reveal_next()

func _reveal_next() -> void:
	if _reveal_index >= _results.size():
		_finish_reveal()
		return
	var r: GachaResultData = _results[_reveal_index]
	_reveal_index += 1
	await _show_card(r)

func _on_tap_advance() -> void:
	if not _awaiting_tap: return
	_awaiting_tap = false
	_reveal_next()

func _show_card(r: GachaResultData) -> void:
	if _skip_all:
		_populate_reveal_panel(r)
		return

	var rcolor := _rarity_color(r.rarity)
	_do_rarity_flash(rcolor, r.rarity == 5)

	_populate_reveal_panel(r)
	reveal_panel.scale    = Vector2(0.82, 0.82)
	reveal_panel.modulate.a = 0.0

	var pan_t := create_tween().set_parallel()
	pan_t.tween_property(reveal_panel, "modulate:a", 1.0, PANEL_FADE)
	pan_t.tween_property(reveal_panel, "scale", Vector2.ONE, PANEL_SCALE_T)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_animate_star_label(r.rarity)

	_awaiting_tap = true
	_pulse_tap_hint()

func _populate_reveal_panel(r: GachaResultData) -> void:
	var rcolor := _rarity_color(r.rarity)

	var stars := ""
	for _i in range(r.rarity): stars += "★"
	star_label.text = stars
	star_label.add_theme_color_override("font_color", rcolor)

	if r.has_method("get_art"):
		reveal_art.texture = r.get_art()
	if r.has_method("get_display_name"):
		reveal_name.text   = r.get_display_name()
	else:
		reveal_name.text   = r.display_name if "display_name" in r else "Wish Drop"
		
	if r.has_method("get_sub_text"):
		reveal_sub.text    = r.get_sub_text()

	var badge_text: String = r.get_duplicate_badge_text() if r.has_method("get_duplicate_badge_text") else ""
	if r.is_new:
		duplicate_badge.text = "✦ NEW ✦"
		duplicate_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		duplicate_badge.visible = true
	elif badge_text != "":
		duplicate_badge.text = badge_text
		if "duplicate_outcome" in r:
			match r.duplicate_outcome:
				GachaResultData.DuplicateOutcome.CONSTELLATION, \
				GachaResultData.DuplicateOutcome.REFINEMENT:
					duplicate_badge.add_theme_color_override("font_color", rcolor)
				GachaResultData.DuplicateOutcome.CONSTELLATION_MAX, \
				GachaResultData.DuplicateOutcome.REFINEMENT_MAX:
					duplicate_badge.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		duplicate_badge.visible = true
	else:
		duplicate_badge.visible = false

	_style_panel(reveal_panel, Color(0.06, 0.06, 0.16, 0.97), rcolor)

func _do_rarity_flash(color: Color, is_5star: bool) -> void:
	var flash_color := Color(color.r, color.g, color.b, 0.0)
	var peak_alpha   := 0.55 if is_5star else 0.32
	rarity_flash.color = flash_color

	var t := create_tween()
	t.tween_property(rarity_flash, "color:a", peak_alpha, FLASH_IN)
	t.tween_property(rarity_flash, "color:a", 0.0, FLASH_OUT)\
		.set_ease(Tween.EASE_OUT)

	if is_5star:
		_show_ray_burst(color)

func _build_ray_burst() -> void:
	var drawer := _RayDrawer.new()
	drawer.name = "RayDrawer"
	ray_burst.add_child(drawer)

func _show_ray_burst(tint: Color) -> void:
	var drawer = ray_burst.get_node_or_null("RayDrawer")
	if not drawer: return
	drawer.ray_color = tint
	ray_burst.visible = true
	ray_burst.modulate.a = 0.0

	var t := create_tween()
	t.tween_property(ray_burst, "modulate:a", 0.70, RAY_FADE_IN)
	t.tween_interval(RAY_HOLD)
	t.tween_property(ray_burst, "modulate:a", 0.0, RAY_FADE_OUT)\
		.set_ease(Tween.EASE_IN)
	t.tween_callback(func(): ray_burst.visible = false)

	var spin := create_tween().set_loops()
	spin.tween_property(drawer, "rotation", drawer.rotation + TAU, 6.0)\
		.set_ease(Tween.EASE_IN_OUT)

func _animate_star_label(rarity: int) -> void:
	if rarity < 4: return
	var t := create_tween().set_loops(3)
	t.tween_property(star_label, "scale", Vector2(1.12, 1.12), 0.14)\
		.set_ease(Tween.EASE_OUT)
	t.tween_property(star_label, "scale", Vector2.ONE, 0.14)\
		.set_ease(Tween.EASE_IN)

func _pulse_tap_hint() -> void:
	var t := create_tween().set_loops()
	t.tween_property(tap_hint, "modulate:a", 0.25, 0.65)\
		.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(tap_hint, "modulate:a", 1.0,  0.65)\
		.set_ease(Tween.EASE_IN_OUT)

# ═════════════════════════════════════════════════════════════════════════════
#  FINISH & SUMMARY GRID
# ═════════════════════════════════════════════════════════════════════════════
func _finish_reveal() -> void:
	_animating    = false
	_awaiting_tap = false

	reveal_panel.visible = false
	skip_all_btn.visible = false
	rarity_flash.color   = Color(0,0,0,0)
	ray_burst.visible    = false

	var t := create_tween()
	t.tween_property(background, "color", CBG, 0.30)

	_build_result_grid()
	grid_scroll.visible = true
	_set_pull_buttons_enabled(true)
	_refresh_ui()

func _build_result_grid() -> void:
	for child in result_grid.get_children(): child.queue_free()

	for i in _results.size():
		var r: GachaResultData = _results[i]
		var card := _make_grid_card(r)
		card.modulate.a = 0.0
		card.position.y += 18.0
		result_grid.add_child(card)

		var delay := float(i) * GRID_STAGGER
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(card, "modulate:a", 1.0, 0.20)
		t.parallel().tween_property(card, "position:y", card.position.y - 18.0, 0.20)\
			.set_ease(Tween.EASE_OUT)

func _make_grid_card(r: GachaResultData) -> PanelContainer:
	var rcolor := _rarity_color(r.rarity)
	var card   := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 138)
	_style_panel(card, rcolor.darkened(0.62), rcolor.lightened(0.15))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var art := TextureRect.new()
	art.custom_minimum_size    = Vector2(76, 76)
	art.stretch_mode           = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.expand_mode            = TextureRect.EXPAND_IGNORE_SIZE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if r.has_method("get_art"):
		art.texture            = r.get_art()
	vbox.add_child(art)

	var stars := ""
	for _i in range(r.rarity): stars += "★"
	var star_lbl := Label.new()
	star_lbl.text = stars
	star_lbl.add_theme_font_size_override("font_size", 11)
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_color_override("font_color", rcolor)
	vbox.add_child(star_lbl)

	var name_lbl := Label.new()
	if r.has_method("get_display_name"):
		name_lbl.text          = r.get_display_name()
	else:
		name_lbl.text          = r.display_name if "display_name" in r else "Drop"
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.autowrap_mode     = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	var badge_text: String = r.get_duplicate_badge_text() if r.has_method("get_duplicate_badge_text") else ""
	if r.is_new:
		badge_text = "NEW"
	if badge_text != "":
		var badge := Label.new()
		badge.text = badge_text
		badge.add_theme_font_size_override("font_size", 9)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var is_max := false
		if "duplicate_outcome" in r:
			is_max = (r.duplicate_outcome == GachaResultData.DuplicateOutcome.CONSTELLATION_MAX or r.duplicate_outcome == GachaResultData.DuplicateOutcome.REFINEMENT_MAX)
			
		var bc := C5 if r.is_new else (Color(1.0, 0.4, 0.4) if is_max else rcolor)
		badge.add_theme_color_override("font_color", bc)
		vbox.add_child(badge)

	return card

# ═════════════════════════════════════════════════════════════════════════════
#  SKIP ALL
# ═════════════════════════════════════════════════════════════════════════════
func _on_skip_all() -> void:
	_skip_all     = true
	_awaiting_tap = false
	_reveal_index = _results.size()
	_finish_reveal()

# ═════════════════════════════════════════════════════════════════════════════
#  NAVIGATION
# ═════════════════════════════════════════════════════════════════════════════
func _on_back() -> void:
	var return_scene: String = ""
	if GameManager != null and GameManager.has_method("get_return_scene"):
		return_scene = GameManager.get_return_scene()

	# If testing with F6 directly, return_scene might be empty
	if return_scene.is_empty() or not ResourceLoader.exists(return_scene):
		print("[GachaSim] Return pressed in F6 simulation mode. Resetting test scene.")
		get_tree().reload_current_scene()
		return

	if GameManager != null:
		GameManager.next_spawn = ""

	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.30)
	t.tween_callback(func():
		if GameManager != null:
			GameManager.pending_zone = return_scene
		get_tree().change_scene_to_file("res://Scenes/Game.tscn")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

# ═════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════════════════════════════════════
func _rarity_color(rarity: int) -> Color:
	match rarity:
		5: return C5
		4: return C4
		_: return C3

func _set_pull_buttons_enabled(enabled: bool) -> void:
	var pulls: int = GachaManager.pulls if GachaManager != null else 0
	pull1_btn.disabled  = not enabled or pulls < 1
	pull10_btn.disabled = not enabled or pulls < 10

func _style_btn(btn: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.08 if state == "hover" else
									 0.16 if state == "pressed" else 0.0)
		_round_corners(s, 10)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _style_pull_btn(btn: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color    = Color(0.48, 0.33, 0.05).lightened(0.08 if state != "normal" else 0.0)
		s.border_color = C5
		for side in ["left","right","top","bottom"]:
			s.set("border_width_" + side, 2)
		_round_corners(s, 12)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", C5)

func _style_progress_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	_round_corners(fill, 5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.14, 0.20)
	_round_corners(bg, 5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)

func _style_panel(panel: PanelContainer, bg: Color,
		border: Color = Color(1,1,1,0.15)) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	for side in ["left","right","top","bottom"]:
		s.set("border_width_" + side, 1)
	_round_corners(s, 14)
	panel.add_theme_stylebox_override("panel", s)

func _round_corners(s: StyleBoxFlat, r: int) -> void:
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		s.set("corner_radius_" + corner, r)

# ═════════════════════════════════════════════════════════════════════════════
#  INNER CLASS — procedural ray-burst drawer
# ═════════════════════════════════════════════════════════════════════════════
class _RayDrawer extends Node2D:
	var ray_color: Color = Color(1.0, 0.85, 0.3)
	const NUM_RAYS  := 18
	const RAY_LEN   := 600.0
	const RAY_WIDTH := 40.0

	func _ready() -> void:
		position = Vector2(640, 360)

	func _draw() -> void:
		for i in NUM_RAYS:
			var angle   := (TAU / NUM_RAYS) * i
			var tip     := Vector2(cos(angle), sin(angle)) * RAY_LEN
			var perp    := Vector2(-sin(angle), cos(angle)) * (RAY_WIDTH * 0.5)
			var col     := Color(ray_color.r, ray_color.g, ray_color.b, 0.28)
			var pts     := PackedVector2Array([
				Vector2.ZERO - perp * 0.2,
				Vector2.ZERO + perp * 0.2,
				tip
			])
			draw_polygon(pts, PackedColorArray([col, col, Color(col.r, col.g, col.b, 0.0)]))
