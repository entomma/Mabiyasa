extends CanvasLayer

@onready var panel = $MarginContainer/PanelContainer
@onready var title_label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var desc_label = $MarginContainer/PanelContainer/VBoxContainer/DescLabel
@onready var objective_label = $MarginContainer/PanelContainer/VBoxContainer/ObjectiveLabel

func _ready():
	apply_minimalist_theme()
	panel.visible = false
	
	TutorialManager.step_changed.connect(show_step)
	TutorialManager.tutorial_step_completed.connect(hide_step)


func show_step(step_name: String):
	if step_name == "movement":
		title_label.text = "Mobility"
		desc_label.text = "Use WASD to move."
		objective_label.text = "Objective: Walk around the area"
		panel.visible = true
	elif step_name == "camera":
		title_label.text = "Look Around"
		desc_label.text = "Move your mouse to look."
		objective_label.text = "Objective: Turn camera"
		panel.visible = true
	elif step_name == "sprint":
		title_label.text = "Sprint"
		desc_label.text = "Hold Shift while moving to sprint."
		objective_label.text = "Objective: Test sprinting speed"
		panel.visible = true
	elif step_name == "interact":
		title_label.text = "Interact"
		desc_label.text = "Press [E] to interact with objects."
		objective_label.text = "Objective: Find an object"
		panel.visible = true


func hide_step(_step_name: String):
	panel.visible = false


func apply_minimalist_theme():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.90) # Dark gray with 90% opacity
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	
	style.border_width_bottom = 3
	style.border_color = Color(0.85, 0.65, 0.15, 0.9) # Gold accent
	
	panel.add_theme_stylebox_override("panel", style)
	
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	objective_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
