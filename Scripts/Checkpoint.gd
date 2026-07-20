extends Area3D

@export var checkpoint_id: String = "checkpoint_1"
@export var scene_name: String = "small_village"  # set this per scene!

var activated: bool = false

@onready var mesh = $MeshInstance3D

func _ready():
	body_entered.connect(_on_body_entered)
	if AccountManager.last_checkpoint == checkpoint_id:
		set_activated_visual()

func _on_body_entered(body):
	if body.is_in_group("player") and not activated:
		activated = true
		set_activated_visual()
		save_checkpoint(body)
		print("Checkpoint reached: ", checkpoint_id, " in ", scene_name)

func set_activated_visual():
	activated = true
	if mesh:
		var mat = StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = Color(1, 0.8, 0)
		mat.albedo_color = Color(1, 0.8, 0)
		mesh.material_override = mat

func save_checkpoint(player) -> void:
	var pos = player.global_position
	# SupabaseManager.save_checkpoint() updates AccountManager itself once the
	# write succeeds, so Checkpoint.gd doesn't need to touch it directly.
	SupabaseManager.save_checkpoint(checkpoint_id, scene_name, pos)
