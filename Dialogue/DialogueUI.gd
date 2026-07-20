extends CanvasLayer
class_name DialogueUI

signal next_pressed
signal choice_selected(next_id: StringName)

@onready var panel: NinePatchRect = $DialogueUI/Panel
@onready var name_label: Label = $DialogueUI/Panel/NameLabel
@onready var dialogue_label: RichTextLabel = $DialogueUI/Panel/DialogueLabel
@onready var next_indicator: Control = $DialogueUI/Panel/NextIndicator
@onready var choice_container: VBoxContainer = $DialogueUI/Panel/ChoiceContainer


func _ready():

	DialogueManager.register_ui(self)

	hide()


func show_line(speaker: String, text: String):

	show()

	name_label.text = speaker
	dialogue_label.text = text

	clear_choices()

	next_indicator.visible = true


func show_choices(choices: Array[DialogueChoice]):

	show()

	clear_choices()

	next_indicator.visible = false

	for choice in choices:

		var button := Button.new()

		button.text = choice.text

		button.pressed.connect(
			func():
				choice_selected.emit(choice.next_id)
		)

		choice_container.add_child(button)


func clear_choices():

	for child in choice_container.get_children():
		child.queue_free()


func hide_dialogue():

	hide()

	clear_choices()


func _unhandled_input(event):

	if !visible:
		return

	if choice_container.get_child_count() > 0:
		return

	if event.is_action_pressed("ui_accept"):
		next_pressed.emit()
		return

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		next_pressed.emit()
