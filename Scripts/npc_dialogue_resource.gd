extends Resource
class_name NPCDialogue

@export_group("Teaching Phase")
@export_multiline var npc_lines: Array[String] = []
## Audio tracks matching each text line in the teaching phase array above
@export var voice_lines: Array[AudioStream] = []

@export_group("Quiz Phase")
@export var quiz_question: String = ""
@export var choices: Array[String] = []
@export var correct_index: int = 0
## OPTIONAL: Voice track for when the NPC asks the quiz question
@export var quiz_voice: AudioStream 

@export_group("Feedback Messages")
@export var success_msg: String = "Correct! Mayap!"
@export var fail_msg: String = "Not quite. Try again!"

@export_group("Feedback Voices")
## OPTIONAL: Voice line played when the player chooses the RIGHT answer
@export var success_voice: AudioStream
## OPTIONAL: Voice line played when the player chooses the WRONG answer
@export var fail_voice: AudioStream
