extends Node3D

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var character_data: CharacterData = null

func _ready():
	if sprite == null:
		push_error("AnimatedSprite3D node not found in " + name)
		return
	print(sprite)

func setup(data: CharacterData, side: String = "player"):
	print("hello",character_data)
	character_data = data
	
	if sprite == null:
		push_error("Cannot setup - sprite is null in " + name)
		return
	
	# Animate dSprite3D uses sprite_frames, not texture
	if data.splash_art:
		var frames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", data.splash_art)
		sprite.sprite_frames = frames
		sprite.animation = "idle"
		sprite.play()
	else:
		# Placeholder
		var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.8))
		var placeholder_tex = ImageTexture.create_from_image(img)
		
		var frames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", placeholder_tex)
		sprite.sprite_frames = frames
		sprite.animation = "idle"
	
	# Flip for enemy
	if side == "enemy":
		sprite.scale = Vector3(-1, 1, 1)
	else:
		sprite.scale = Vector3(1, 1, 1)
