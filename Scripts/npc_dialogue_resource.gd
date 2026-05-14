extends Resource
class_name NPCDialogue

@export_group("Teaching Phase")
@export_multiline var npc_lines: Array[String] = []

@export_group("Quiz Phase")
@export var quiz_question: String = ""
@export var choices: Array[String] = []
@export var correct_index: int = 0

@export_group("Feedback")
@export var success_msg: String = "Correct! Mayap!"
@export var fail_msg: String = "Not quite. Try again!"
