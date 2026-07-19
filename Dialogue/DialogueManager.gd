extends Node

signal dialogue_started
signal dialogue_finished
signal action_requested(action: String, parameter: String)

var dialogue_ui: DialogueUI

var current_dialogue: DialogueResource
var current_event: DialogueEvent

var events := {}

func register_ui(ui: DialogueUI):
	dialogue_ui = ui

	if !dialogue_ui.next_pressed.is_connected(_on_next_pressed):
		dialogue_ui.next_pressed.connect(_on_next_pressed)

	if !dialogue_ui.choice_selected.is_connected(_on_choice_selected):
		dialogue_ui.choice_selected.connect(_on_choice_selected)


func start(dialogue: DialogueResource):

	if dialogue_ui == null:
		push_error("DialogueUI has not been registered.")
		return

	if dialogue == null:
		return

	current_dialogue = dialogue
	events.clear()

	for event in dialogue.events:
		events[event.id] = event

	current_event = dialogue.events[0]

	dialogue_started.emit()

	_show_current_event()


func _show_current_event():

	match current_event.type:

		DialogueEvent.EventType.LINE:
			dialogue_ui.show_line(
				current_event.speaker,
				current_event.text
			)

		DialogueEvent.EventType.CHOICE:
			dialogue_ui.show_choices(
				current_event.choices
			)

		DialogueEvent.EventType.ACTION:
			action_requested.emit(
				current_event.action,
				current_event.parameter
			)

			_go_to(current_event.next_id)

		DialogueEvent.EventType.END:
			end_dialogue()


func _on_next_pressed():

	if current_event.next_id == StringName():
		end_dialogue()
		return

	_go_to(current_event.next_id)


func _on_choice_selected(next_id: StringName):

	_go_to(next_id)


func _go_to(id: StringName):

	if !events.has(id):
		end_dialogue()
		return

	current_event = events[id]

	_show_current_event()


func end_dialogue():

	if dialogue_ui:
		dialogue_ui.hide_dialogue()

	current_dialogue = null
	current_event = null

	events.clear()

	dialogue_finished.emit()
