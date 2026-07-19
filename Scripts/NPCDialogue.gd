extends Node

@export var dialogue: DialogueResource

var player_in_range := false

func _on_area_3d_body_entered(body):

	if body.is_in_group("player"):
		player_in_range = true


func _on_area_3d_body_exited(body):

	if body.is_in_group("player"):
		player_in_range = false


func _input(event):

	if !player_in_range:
		return

	if DialogueManager.is_active:
		return

	if event.is_action_pressed("interact"):

		if dialogue:
			DialogueManager.start(dialogue)

			get_viewport().set_input_as_handled()
