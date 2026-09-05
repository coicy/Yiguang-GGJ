extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ground := _make_ground()
	root.add_child(ground)
	var player := preload("res://features/player/player.tscn").instantiate() as Player
	root.add_child(player)
	player.global_position = Vector2(0.0, -1.0)
	await _physics_steps(6)

	assert(player.is_on_floor())
	assert(player.current_form_id() == &"sprout")
	assert(not player.abilities.try_root())
	assert(player.form_controller.restore_form(&"humanoid"))
	await physics_frame
	_press_primary(player)
	await _physics_steps(2)
	assert(player.abilities.is_rooted())
	assert(is_zero_approx(player.velocity.x))
	player.abilities.leg_extension_speed = 240.0
	player.abilities.leg_retraction_speed = 480.0
	var start_position := player.global_position
	var leg_anchor := player.abilities.get_leg_anchor_global_position()
	Input.action_press(&"move_right")
	await _physics_steps(2)
	assert(player.abilities.is_leg_extended())
	var first_length: float = player.abilities.get_leg_length()
	assert(first_length > 0.0)
	assert(first_length < player.abilities.get_max_leg_length())
	assert(player.abilities.leg_area().monitoring)
	var first_tip: Vector2 = player.abilities.get_leg_path()[1]
	assert(is_zero_approx(first_tip.y))
	assert(first_tip.x < 0.0)
	assert(player.abilities.get_leg_anchor_global_position().is_equal_approx(leg_anchor))
	await _physics_steps(4)
	var second_length: float = player.abilities.get_leg_length()
	assert(second_length > first_length)
	assert(player.global_position.x > start_position.x)
	var max_length: float = player.abilities.get_max_leg_length()
	Input.action_press(&"move_up")
	Input.action_release(&"move_right")
	await _physics_steps(2)
	var turned_path: PackedVector2Array = player.abilities.get_leg_path()
	assert(turned_path.size() >= 3)
	var corner: Vector2 = turned_path[1]
	var tip: Vector2 = turned_path[turned_path.size() - 1]
	assert(is_zero_approx(corner.x))
	assert(corner.y > 0.0)
	assert(tip.x < corner.x)
	assert(is_equal_approx(tip.y, corner.y))
	assert((player.global_position + tip).is_equal_approx(leg_anchor))
	assert(player.abilities.get_leg_length() <= max_length + 0.01)
	player.abilities.set_leg_extension_direction(Vector2(1.0, -1.0))
	assert(player.abilities.get_leg_extension_direction() == Vector2.UP)
	await _physics_steps(60)
	assert(is_equal_approx(player.abilities.get_leg_length(), max_length))
	Input.action_release(&"move_up")
	await _physics_steps(2)
	var released_length: float = player.abilities.get_leg_length()
	assert(released_length < max_length)
	await _physics_steps(4)
	assert(player.abilities.get_leg_length() < released_length)
	assert(player.abilities.is_rooted())
	for _step: int in range(60):
		if not player.abilities.is_leg_extended():
			break
		await physics_frame
	assert(not player.abilities.is_leg_extended(), "Releasing movement must retract the body all the way to its fixed leg anchor.")
	assert(player.global_position.distance_to(leg_anchor) <= 2.1)
	assert(player.abilities.is_rooted())
	var step_platform := _make_step_platform()
	root.add_child(step_platform)
	_release_primary(player)
	await _physics_steps(2)
	assert(player.abilities.is_rooted())
	_press_primary(player)
	assert(not player.abilities.is_rooted())
	player.cancel_actions()
	assert(not player.abilities.is_leg_extended())

	assert(player.form_controller.restore_form(&"mature"))
	player.global_position = Vector2(0.0, -100.0)
	player.velocity.y = 500.0
	player.movement.tick(0.1, 0.0, true)
	assert(player.velocity.y <= player.form_controller.get_current().glide_fall_speed)
	var off_direction_anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
	root.add_child(off_direction_anchor)
	off_direction_anchor.global_position = player.global_position + Vector2(40.0, -40.0)
	var aimed_anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
	root.add_child(aimed_anchor)
	aimed_anchor.global_position = player.global_position + Vector2(180.0, 0.0)
	_press_primary(player, aimed_anchor.global_position)
	await _physics_steps(2)
	assert(player.abilities.get_vine_anchor() == aimed_anchor, "Vine must attach to the anchor in the mouse direction.")
	player.abilities.stop_primary()
	off_direction_anchor.free()
	aimed_anchor.free()

	var anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
	root.add_child(anchor)
	anchor.global_position = player.global_position + Vector2(120.0, -160.0)
	_press_primary(player, anchor.global_position)
	await _physics_steps(2)
	assert(player.abilities.is_vine_attached())
	var length_before := player.global_position.distance_to(anchor.global_position)
	player.velocity = Vector2.ZERO
	var normal_acceleration := player.movement.acceleration
	var normal_gravity := player.movement.gravity
	player.movement.acceleration = 0.0
	player.movement.gravity = 0.0
	player.movement.tick(0.1, 1.0, false)
	var accelerated_speed := player.velocity.x
	assert(accelerated_speed > 0.0)
	player.movement.tick(0.1, -1.0, false)
	assert(player.velocity.x < accelerated_speed)
	player.movement.gravity = normal_gravity
	player.movement.acceleration = normal_acceleration
	assert(player.global_position.distance_to(anchor.global_position) <= length_before + 1.0)
	anchor.global_position = Vector2(0.0, -500.0)
	var glide_test_angle := deg_to_rad(70.0)
	player.global_position = anchor.global_position + Vector2(sin(glide_test_angle), cos(glide_test_angle)) * 200.0
	player.movement.attach_vine(anchor, 200.0)
	player.velocity = Vector2(0.0, 500.0)
	player.movement.request_jump()
	assert(is_zero_approx(player.movement.jump_buffer_remaining()))
	player.movement.tick(0.1, 0.0, true)
	assert(player.velocity.y > player.form_controller.get_current().glide_fall_speed)
	var max_swing_angle := deg_to_rad(player.movement.vine_max_swing_angle_degrees)
	var beyond_limit := max_swing_angle + 0.2
	player.global_position = anchor.global_position + Vector2(sin(beyond_limit), cos(beyond_limit)) * 200.0
	player.velocity = Vector2(600.0, -600.0)
	player.movement.tick(0.01, 1.0, false)
	var right_radial := player.global_position - anchor.global_position
	assert(atan2(right_radial.x, right_radial.y) <= max_swing_angle + 0.01)
	player.global_position = anchor.global_position + Vector2(-sin(beyond_limit), cos(beyond_limit)) * 200.0
	player.velocity = Vector2(-600.0, -600.0)
	player.movement.tick(0.01, -1.0, false)
	var left_radial := player.global_position - anchor.global_position
	assert(atan2(left_radial.x, left_radial.y) >= -max_swing_angle - 0.01)
	_release_primary(player)
	assert(player.abilities.is_vine_attached())
	_press_primary(player)
	assert(not player.abilities.is_vine_attached())

	player.free()
	anchor.free()
	step_platform.free()
	ground.free()
	# Let queued nodes and the audio mixer release stopped playback before shutdown.
	await process_frame
	await create_timer(0.1).timeout
	quit()


func _make_ground() -> StaticBody2D:
	var ground := StaticBody2D.new()
	ground.position = Vector2(0.0, 10.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(500.0, 20.0)
	collision.shape = shape
	ground.add_child(collision)
	return ground


func _make_step_platform() -> StaticBody2D:
	var platform := StaticBody2D.new()
	platform.position = Vector2(100.0, -24.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80.0, 48.0)
	collision.shape = shape
	platform.add_child(collision)
	return platform


func _physics_steps(count: int) -> void:
	for _step in count:
		await physics_frame


func _press_primary(player: Player, mouse_position: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = mouse_position
	event.pressed = true
	player._unhandled_input(event)


func _release_primary(player: Player) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	player._unhandled_input(event)
