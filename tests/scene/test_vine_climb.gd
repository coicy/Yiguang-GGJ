extends SceneTree
## Ring climbing uses the full player shape and never crosses solid geometry.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := preload("res://features/player/player.tscn").instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	assert(player.form_controller.restore_form(&"mature"))
	var anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
	root.add_child(anchor)
	anchor.position = Vector2(0.0, -200.0)
	player.position = Vector2(0.0, -80.0)
	await physics_frame
	_press_climb(player)
	player._physics_process(1.0 / 60.0)
	assert(not player.abilities.is_vine_attached(), "E alone must not attach a ring.")
	assert(player.position.y > anchor.position.y)
	assert(player.abilities.try_attach_vine())
	var climb_start := player.position
	_press_climb(player)
	player._physics_process(1.0 / 60.0)
	assert(player.movement.is_vine_climbing(), "E must begin a multi-frame climb.")
	assert(player.abilities.is_vine_attached(), "The rope stays attached during the climb.")
	assert(player.position.distance_to(climb_start) > 0.0)
	assert(player.position.distance_to(climb_start) < climb_start.distance_to(anchor.position), "Climbing must not teleport in one frame.")
	var x_during_climb := player.position.x
	Input.action_press(&"move_right")
	player._physics_process(1.0 / 60.0)
	Input.action_release(&"move_right")
	assert(is_equal_approx(player.position.x, x_during_climb), "Normal movement input must be locked during climbing.")
	for step: int in range(120):
		player._physics_process(1.0 / 60.0)
		if not player.abilities.is_vine_attached():
			break
		await physics_frame
	assert(not player.abilities.is_vine_attached(), "Climbing must release the rope on arrival.")
	assert(absf(player.position.x - anchor.position.x) < 1.0)
	assert(player.position.y <= anchor.position.y - 12.0, "Feet must reach above the ring.")
	assert(player.position.y >= anchor.position.y - 20.0)

	# A thin obstacle at head height leaves the point above the ring clear,
	# but there is insufficient room for the player's complete body.
	player.position = Vector2(0.0, -80.0)
	player.velocity = Vector2.ZERO
	var obstacle := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80.0, 8.0)
	collision.shape = shape
	obstacle.add_child(collision)
	obstacle.position = anchor.position + Vector2(0.0, -40.0)
	root.add_child(obstacle)
	await physics_frame
	assert(player.abilities.try_attach_vine())
	_press_climb(player)
	player._physics_process(1.0 / 60.0)
	assert(not player.movement.is_vine_climbing(), "Blocked destination must not start climbing.")
	assert(player.abilities.is_vine_attached(), "Blocked destination must preserve attachment.")
	assert(player.position.y > anchor.position.y)

	# Move the obstacle into the travel path after attachment.
	shape.size = Vector2(400.0, 8.0)
	obstacle.position = Vector2(0.0, -145.0)
	await physics_frame
	_press_climb(player)
	for step: int in range(90):
		player._physics_process(1.0 / 60.0)
		await physics_frame
	assert(player.position.y > obstacle.position.y, "Climbing must not cross a solid obstacle.")
	player.cancel_actions()
	assert(not player.abilities.is_vine_attached())
	player.free()
	anchor.free()
	obstacle.free()
	print("Vine climb scene checks passed.")
	quit()


func _press_climb(player: Player) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	player._unhandled_input(event)
