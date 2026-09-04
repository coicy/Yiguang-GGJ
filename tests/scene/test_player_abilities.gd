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
	assert(player.abilities.toggle_primary())
	assert(player.abilities.is_rooted())
	player.abilities.set_leg_extension_direction(Vector2.UP)
	assert(player.abilities.is_leg_extended())
	assert(player.abilities.get_leg_extension_direction() == Vector2.UP)
	await physics_frame
	assert(player.abilities.leg_area().monitoring)
	assert(player.abilities.toggle_primary())
	assert(not player.abilities.is_rooted())
	assert(not player.abilities.is_leg_extended())
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
	assert(player.abilities.try_attach_vine())
	assert(player.abilities.is_vine_attached())
	var length_before := player.global_position.distance_to(anchor.global_position)
	player.velocity = Vector2.ZERO
	var normal_acceleration := player.movement.acceleration
	player.movement.acceleration = 0.0
	player.movement.tick(0.1, 1.0, false)
	player.movement.acceleration = normal_acceleration
	assert(player.velocity.x > 0.0)
	assert(player.global_position.distance_to(anchor.global_position) <= length_before + 1.0)
	player.abilities.stop_primary()
	assert(not player.abilities.is_vine_attached())

	player.free()
	anchor.free()
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


func _physics_steps(count: int) -> void:
	for _step in count:
		await physics_frame
