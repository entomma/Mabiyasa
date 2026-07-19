extends Resource
class_name DialogueEvent

enum EventType {
	LINE,
	CHOICE,
	ACTION,
	END
}

@export var id: StringName

@export var next_id: StringName

@export var type: EventType = EventType.LINE

@export var speaker: String

@export_multiline var text: String

@export var choices: Array[DialogueChoice]

@export var action: String

@export var parameter: String
