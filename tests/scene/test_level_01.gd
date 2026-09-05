extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/level_01.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_SCENE.instantiate() as Node2D
	root.add_child(level)
	await physics_frame

	var bounds := level.get_node("CameraBounds") as CameraBounds
	assert(bounds.get_world_rect().is_equal_approx(Rect2(-256.0, -128.0, 1008.0, 1040.0)))
	var player := level.get_node("Actors/Player") as Player
	var camera := player.get_node("Camera2D") as Camera2D
	assert(camera.limit_left == -256 and camera.limit_top == -128)
	assert(camera.limit_right == 752 and camera.limit_bottom == 912)
	_assert_uniform_art_scaling(level)

	var b1 := level.get_node("Mechanisms/B1") as TriggerButton
	var b2 := level.get_node("Mechanisms/B2") as TriggerButton
	var b3 := level.get_node("Mechanisms/B3") as TriggerButton
	var b4 := level.get_node("Mechanisms/B4") as TriggerButton
	assert(b1.press(player) and b2.press(player) and b3.press(player) and b4.press(player))
	await _wait_for_motion(level)

	var c1 := level.get_node("Mechanisms/C1") as MoveableCube
	var c2 := level.get_node("Mechanisms/C2") as MoveableCube
	var c6 := level.get_node("Mechanisms/C6") as MoveableCube
	assert(is_equal_approx(c1.global_rotation, PI * 0.5))
	assert(is_equal_approx(c2.global_rotation, PI * 0.5))
	assert(is_equal_approx(c6.global_rotation, PI * 0.5))
	assert((level.get_node("Mechanisms/C5") as MoveableCube).global_position.is_equal_approx(Vector2(176.0, 288.0)))
	assert((level.get_node("Mechanisms/C3") as MoveableCube).global_position.is_equal_approx(Vector2(160.0, -128.0)))
	assert((level.get_node("Mechanisms/C4") as MoveableCube).global_position.is_equal_approx(Vector2(48.0, -128.0)))
	assert(not b1.press(player), "Buttons must remain latched after activation.")

	level.queue_free()
	quit()


func _wait_for_motion(level: Node) -> void:
	for _step: int in range(480):
		var moving := false
		for cube_name: String in ["C1", "C2", "C3", "C4", "C5", "C6"]:
			moving = moving or (level.get_node("Mechanisms/%s" % cube_name) as MoveableCube).is_moving()
		if not moving:
			return
		await physics_frame
	assert(false, "Level 01 mechanisms did not settle within eight seconds.")


func _assert_uniform_art_scaling(level: Node) -> void:
	for node: Node in _descendants(level):
		var canvas_item := node as Node2D
		if canvas_item != null:
			assert(is_equal_approx(absf(canvas_item.scale.x), absf(canvas_item.scale.y)), "%s uses non-uniform art scaling." % node.get_path())
		var collision := node as CollisionShape2D
		if collision != null:
			assert(collision.scale.is_equal_approx(Vector2.ONE), "%s scales a collision node." % node.get_path())


func _descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in parent.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
