extends CanvasLayer

@onready var welcome_box = $WelcomeBox
@onready var start_button = $WelcomeBox/PanelContainer/VBoxContainer/StartButton
@onready var sidebar_box = $SidebarBox
@onready var task_title = $SidebarBox/MarginContainer/VBoxContainer/TaskTitle
@onready var task_desc = $SidebarBox/MarginContainer/VBoxContainer/TaskDesc
@onready var progress_bar = $SidebarBox/MarginContainer/VBoxContainer/ProgressBar

var text_database = {
	"movement": {
		"title": "1. Basic Mobility",
		"desc": "Calibrating systems... Walk 25 meters using your WASD or Directional Arrow Keys.",
		"show_bar": true
	},
	"camera": {
		"title": "2. Environment Scan",
		"desc": "Locomotion verified. Move your mouse horizontally to look around and pan the frame.",
		"show_bar": true
	},
	"sprint": {
		"title": "3. Sprint Burst",
		"desc": "Optics calibrated. While walking in any direction, press and hold [SHIFT] to test sprinting speed.",
		"show_bar": false
	},
	"interact": {
		"title": "4. Interacting",
		"desc": "Find an interactive object/NPC and push [Space] or [E] to verify item manipulation.",
		"show_bar": false
	},
	"completed": {
		"title": "System Ready",
		"desc": "All system configurations successfully established! Proceeding to core game simulation...",
		"show_bar": false
	}
}


func _ready() -> void:
	# Apply visual styling matching our gold/dark minimalist overlay theme
	apply_minimalist_theme()

	# If the tutorial is already finished, don't show any overlay panels
	if TutorialManager.current_active_step == "finished":
		welcome_box.visible = false
		sidebar_box.visible = false
		return
		
	welcome_box.visible = true
	sidebar_box.visible = false
	progress_bar.visible = false
	
	start_button.pressed.connect(_on_start_pressed)
	TutorialManager.step_changed.connect(_on_step_changed)
	TutorialManager.progress_updated.connect(_on_progress_bar_updated)


func _on_start_pressed() -> void:
	welcome_box.visible = false
	sidebar_box.visible = true
	TutorialManager.start_tutorial()


func _on_step_changed(step_name: String) -> void:
	if step_name == "finished":
		sidebar_box.visible = false
		return

	if text_database.has(step_name):
		var data = text_database[step_name]
		task_title.text = data["title"]
		task_desc.text = data["desc"]
		
		progress_bar.visible = data["show_bar"]
		progress_bar.value = 0


func _on_progress_bar_updated(current: float, target: float) -> void:
	progress_bar.max_value = target
	progress_bar.value = current


# ═══════════════════════════════════════════════════════
#  Procedural Theme Injector
# ═══════════════════════════════════════════════════════
func apply_minimalist_theme() -> void:
	# 1. Base Dark Panel Style with Gold Bottom Accent
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.90) # Dark slate gray
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.85, 0.65, 0.15, 0.9) # Accent gold
	
	# 2. Style the Welcome Box background panel
	var welcome_panel = welcome_box.get_node_or_null("PanelContainer")
	if welcome_panel and welcome_panel is PanelContainer:
		welcome_panel.add_theme_stylebox_override("panel", panel_style)
		
	# 3. Style the Sidebar Container
	if sidebar_box is PanelContainer:
		sidebar_box.add_theme_stylebox_override("panel", panel_style)
	else:
		var sidebar_inner_panel = sidebar_box.get_node_or_null("PanelContainer")
		if sidebar_inner_panel and sidebar_inner_panel is PanelContainer:
			sidebar_inner_panel.add_theme_stylebox_override("panel", panel_style)

	# 4. Color text elements to coordinate with theme
	task_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35)) # Gold
	task_desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9)) # Crisp light gray
	
	# 5. Stylize the Godot Start Button dynamically
	if start_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.12, 0.12, 0.15, 1.0)
		btn_normal.border_width_bottom = 2
		btn_normal.border_color = Color(0.85, 0.65, 0.15, 0.8) # Muted gold
		btn_normal.corner_radius_top_left = 4
		btn_normal.corner_radius_top_right = 4
		btn_normal.corner_radius_bottom_left = 4
		btn_normal.corner_radius_bottom_right = 4
		btn_normal.content_margin_top = 8
		btn_normal.content_margin_bottom = 8
		
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color(0.18, 0.18, 0.22, 1.0)
		btn_hover.border_color = Color(0.95, 0.85, 0.35, 1.0) # Highlight gold
		
		start_button.add_theme_stylebox_override("normal", btn_normal)
		start_button.add_theme_stylebox_override("hover", btn_hover)
		start_button.add_theme_stylebox_override("pressed", btn_normal)
		start_button.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))

	# 6. Stylize progress bar nodes matching gold metrics
	if progress_bar:
		var bar_bg = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.04, 0.04, 0.05, 0.8) # Charcoal groove
		bar_bg.corner_radius_top_left = 4
		bar_bg.corner_radius_top_right = 4
		bar_bg.corner_radius_bottom_left = 4
		bar_bg.corner_radius_bottom_right = 4
		
		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.85, 0.65, 0.15, 0.9) # Gold fluid fill
		bar_fill.corner_radius_top_left = 4
		bar_fill.corner_radius_top_right = 4
		bar_fill.corner_radius_bottom_left = 4
		bar_fill.corner_radius_bottom_right = 4
		
		progress_bar.add_theme_stylebox_override("background", bar_bg)
		progress_bar.add_theme_stylebox_override("fill", bar_fill)
		progress_bar.add_theme_color_override("font_color", Color(1, 1, 1, 0)) # Clean look (hides flat % labels)
