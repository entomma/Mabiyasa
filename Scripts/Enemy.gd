extends Area3D

@export var enemy_data: Resource

func _ready():
	print("Enemy loaded!")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Something entered: ", body.name)
	print("Is in player group: ", body.is_in_group("player"))
	print("Groups: ", body.get_groups())
	if body.is_in_group("player"):
		print("Enemy touched! Starting combat...")
		GameManager.start_combat(self, enemy_data)
