extends SceneTree
## Integration test: actual physics movement must request and play footsteps.

const WALK_TEST_SCENE: PackedScene = preload("res://features/audio/walk_sound_test.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := WALK_TEST_SCENE.instantiate() as Node2D
	root.add_child(scene)
	for step: int in range(30):
		await physics_frame
	Input.action_press(&"move_right")
	for step: int in range(45):
		await physics_frame
	Input.action_release(&"move_right")
	await physics_frame

	var count_label := scene.get_node(^"CountLabel") as Label
	assert(count_label.text != "已播放脚步：0", "Walking in the test scene must play a footstep cue.")
	scene.free()
	print("PASS: walk test movement emits and plays footstep cues")
	quit(0)

