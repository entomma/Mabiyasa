extends Control
class_name DialogueUI

signal next_pressed
signal choice_selected(next_id: StringName)

@onready var name_label: Label = $Panel/NameLabel
@onready var dialogue_label: RichTextLabel = $Panel/DialogueLabel
@onready var next_indicator: Control = $Panel/NextIndicator
@onready var choice_container: VBoxContainer = $Panel/ChoiceContainer


func _ready():
	hide()


func show_line(speaker: String, text: String):
	show()

	name_label.text = speaker
	dialogue_label.text = text

	next_indicator.show()

	clear_choices()


func show_choices(choices: Array[DialogueChoice]):
	show()

	next_indicator.hide()

	clear_choices()

	for choice in choices:
		var button := Button.new()

		button.text = choice.text

		button.pressed.connect(func():
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
