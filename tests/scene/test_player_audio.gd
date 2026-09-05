extends SceneTree
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
var cues: Array[StringName] = []
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 40.0)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = 40.0
	root.add_child(floor_body)
	var player := PLAYER.instantiate() as Player
	player.position = Vector2(0.0, 20.0)
	root.add_child(player)
	player.audio.sounds.cue_played.connect(func(cue: StringName) -> void: cues.append(cue))
	for step: int in range(20):
		await physics_frame
	Input.action_press("move_right")
	for step: int in range(50):
		await physics_frame
	Input.action_release("move_right")
	assert(cues.has(&"step_grass"), "Grounded movement must produce footsteps.")
	Input.action_press("jump")
	for step: int in range(4):
		await physics_frame
	Input.action_release("jump")
	for step: int in range(80):
		await physics_frame
	assert(cues.count(&"jump") == 1 and cues.has(&"land"), "Actual jump and landing must produce one-shot feedback.")
	var idle_steps := cues.count(&"step_grass")
	for step: int in range(25):
		await physics_frame
	assert(cues.count(&"step_grass") == idle_steps, "Idle must not produce footsteps.")
	player.absorb_nutrition(100.0)
	assert(cues.count(&"grow") == 1)
	assert(player.abilities.try_root())
	assert(cues.count(&"root") == 1)
	Input.action_press("move_up")
	for step: int in range(5):
		await physics_frame
	assert(cues.count(&"extend") == 1)
	Input.action_release("move_up")
	player.abilities.stop_primary()
	for step: int in range(25):
		await physics_frame
	player.absorb_nutrition(120.0)
	var anchor := VineAnchor.new()
	anchor.position = player.global_position + Vector2(0.0, -80.0)
	root.add_child(anchor)
	await physics_frame
	assert(player.abilities.try_attach_vine())
	assert(cues.count(&"vine") == 1)
	player.abilities.stop_primary()
	await physics_frame
	player.absorb_toxin(120.0)
	assert(cues.count(&"wither") == 1)
	var absorption_count := cues.count(&"absorb")
	for step: int in range(20):
		player.absorb_nutrition(0.1)
		await physics_frame
	assert(cues.count(&"absorb") - absorption_count <= 1, "Absorption feedback must not restart every physics tick.")
	assert(player.audio.sounds.get_child_count() == 6, "Sound voices stay bounded.")
	for voice: Node in player.audio.sounds.get_children():
		var sound := voice as AudioStreamPlayer
		if sound.stream != null:
			assert(sound.stream.get_length() > 0.0)
	player.queue_free()
	anchor.queue_free()
	floor_body.queue_free()
	print("PASS: actual locomotion, form and ability audio; idle silence and absorption throttling")
	# Let queued nodes and the audio mixer release stopped playback before shutdown.
	await process_frame
	await create_timer(0.1).timeout
	quit(0)
