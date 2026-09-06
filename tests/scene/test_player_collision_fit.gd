extends SceneTree
## Reusable player contract; no separate playable test level.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := load("res://features/player/player.tscn").instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(400, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	floor_body.position.y = 110.0
	root.add_child(floor_body)
	for form_id: StringName in [&"sprout", &"humanoid", &"mature"]:
		assert(player.form_controller.switch_to(form_id))
		player.position = Vector2(0, 60)
		for frame: int in range(30):
			await physics_frame
			player.velocity = Vector2(0, 200)
			player.move_and_slide()
		assert(player.is_on_floor(), "%s must land" % form_id)
		assert(absf(player.position.y - 100.0) < 0.1, "%s collision feet must meet floor" % form_id)
		var height: float = {&"sprout": 20.0, &"humanoid": 28.0, &"mature": 38.0}[form_id]
		var shape_bounds := player.collision_shape.shape.get_rect()
		assert(is_equal_approx(shape_bounds.size.y, height))
		assert(is_equal_approx(player.collision_shape.position.y + shape_bounds.position.y, -height))
		# A ceiling one pixel above the fitted head must allow a short rise.
		var ceiling := StaticBody2D.new()
		var ceiling_shape := CollisionShape2D.new()
		ceiling_shape.shape = rectangle
		ceiling.add_child(ceiling_shape)
		ceiling.position.y = 100.0 - height - 11.0
		root.add_child(ceiling)
		await physics_frame
		assert(not player.test_move(player.global_transform, Vector2(0, -0.5)))
		assert(player.test_move(player.global_transform, Vector2(0, -2.0)))
		ceiling.free()
		var visual := player.visuals.visual_host.get_child(0) as SpineCharacterVisual
		assert(visual.play_animation(&"move", true))
		player.visuals.set_grounded(true)
		for frame: int in range(20):
			visual.spine_sprite.update_skeleton(0.05)
			player.visuals._align_grounded_visual()
			var bounds: Rect2 = visual.spine_sprite.get_skeleton().get_bounds()
			assert(absf(player.visuals.visual_host.position.y + bounds.end.y * visual.scale.y) < 0.05)
		player.visuals.set_grounded(false)
		player.visuals._align_grounded_visual()
		assert(player.visuals.visual_host.position == player.form_controller.get_current().visual_offset)
	player.free()
	floor_body.free()
	print("PASS: three forms land at their feet, fit ceilings, and keep grounded animation feet aligned")
	quit()
