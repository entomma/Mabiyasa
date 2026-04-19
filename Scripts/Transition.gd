extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var anim_player = $AnimationPlayer

var target_scene: String = ""

func _ready():
	color_rect.modulate.a = 0
	# Add fade in animation
	if not anim_player.has_animation("fade_in"):
		var anim = Animation.new()
		anim.length = 0.8
		var track = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, "ColorRect:modulate:a")
		anim.track_insert_key(track, 0.0, 1.0)
		anim.track_insert_key(track, 0.8, 0.0)
		var anim_lib = AnimationLibrary.new()
		anim_lib.add_animation("fade_in", anim)
		anim_player.add_animation_library("", anim_lib)

func start_transition(next_scene: String):
	"""FULL transition: fade + change scene"""
	target_scene = next_scene
	
	# Zoom effect
	var camera = get_tree().get_first_node_in_group("camera")
	print("Camera found: ", camera)
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "fov", 30.0, 0.8)
	
	if anim_player.has_animation("zoom_fade"):
		print("Playing zoom_fade animation")
		anim_player.play("zoom_fade")
		await anim_player.animation_finished
	else:
		print("Animation missing!")
		await get_tree().create_timer(1.0).timeout
	
	get_tree().change_scene_to_file(target_scene)

func start_transition_fade():
	"""FADE ONLY: for combat transitions (scene change happens separately)"""
	# Zoom effect
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "fov", 30.0, 0.8)
	
	if anim_player.has_animation("zoom_fade"):
		anim_player.play("zoom_fade")
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout

func fade_in():
	color_rect.modulate.a = 1.0
	anim_player.play("fade_in")
