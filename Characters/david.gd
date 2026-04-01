extends Node3D

var character_data: CharacterData = null
var sprite: AnimatedSprite3D = null

func _ready():
	for child in get_children():
		if child is AnimatedSprite3D:
			sprite = child
			break

func setup(data: CharacterData, side: String = "player"):
	character_data = data
	
	if sprite == null:
		await ready
		for child in get_children():
			if child is AnimatedSprite3D:
				sprite = child
				break
	
	if sprite == null:
		push_error("Cannot setup - no sprite found in " + name)
		return
	
	# DON'T override sprite_frames if already set in the scene
	# Only set splash art if NO frames exist at all
	if sprite.sprite_frames == null or sprite.sprite_frames.get_animation_list().is_empty():
		if data.splash_art:
			var frames = SpriteFrames.new()
			frames.add_animation("idle")
			frames.add_frame("idle", data.splash_art)
			sprite.sprite_frames = frames
			sprite.animation = "idle"
			sprite.play()
	else:
		# Play existing animation from scene
		sprite.play()
	
	# Flip for enemy
	if side == "enemy":
		sprite.scale.x = abs(sprite.scale.x) * -1
	else:
		sprite.scale.x = abs(sprite.scale.x)
