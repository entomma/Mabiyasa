extends MultiMeshInstance3D

@export var source_mesh: Mesh
@export var parent_holder: NodePath

func _ready():
	var holder = get_node(parent_holder)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = source_mesh
	mm.instance_count = holder.get_child_count()

	for i in holder.get_child_count():
		var obj = holder.get_child(i)
		mm.set_instance_transform(i, obj.global_transform)

	multimesh = mm
