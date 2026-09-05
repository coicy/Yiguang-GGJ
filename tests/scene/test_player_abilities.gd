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
	player.velocity.x = 240.0
	Input.action_press(&"ability_primary")
	await _physics_steps(2)
	assert(player.abilities.is_rooted())
	assert(is_zero_approx(player.velocity.x))
	Input.action_press(&"move_up")
	await _physics_steps(2)
	assert(player.abilities.is_leg_extended())
	assert(player.abilities.get_leg_extension_direction() == Vector2.UP)
	assert(player.abilities.leg_area().monitoring)
	var extended_shape := player.collision_shape.shape as RectangleShape2D
	assert(extended_shape.size.y == player.form_controller.get_current().collision_size.y + Player.LEG_EXTENSION_HEIGHT)
	var step_platform := _make_step_platform()
	root.add_child(step_platform)
	Input.action_release(&"move_up")
	Input.action_press(&"move_right")
	await _physics_steps(2)
	Input.action_release(&"move_right")
	assert(player.abilities.get_leg_extension_direction() == Vector2.RIGHT)
	assert(is_zero_approx(player.velocity.x))
	await _physics_steps(2)
	assert(not player.abilities.is_leg_extended())
	assert(extended_shape.size == player.form_controller.get_current().collision_size)
	Input.action_release(&"ability_primary")
	await _physics_steps(1)
	Input.action_press(&"ability_primary")
	await _physics_steps(2)
	assert(not player.abilities.is_rooted())
	Input.action_release(&"ability_primary")
	await _physics_steps(1)
	player.cancel_actions()
	assert(not player.abilities.is_leg_extended())

	assert(player.form_controller.restore_form(&"mature"))
	player.global_position = Vector2(0.0, -100.0)
	player.velocity.y = 500.0
	player.movement.tick(0.1, 0.0, true)
	assert(player.velocity.y <= player.form_controller.get_current().glide_fall_speed)

	var anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
	root.add_child(anchor)
	anchor.global_position = player.global_position + Vector2(120.0, -160.0)
	Input.action_press(&"ability_primary")
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
	Input.action_release(&"ability_primary")
	await _physics_steps(1)
	Input.action_press(&"ability_primary")
	await _physics_steps(2)
	assert(not player.abilities.is_vine_attached())

	player.free()
	anchor.free()
	step_platform.free()
	ground.free()
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
