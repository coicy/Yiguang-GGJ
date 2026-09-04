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

	var nutrition_tank := preload("res://features/level/nutrition_tank.tscn").instantiate() as NutritionTank
	nutrition_tank.position = Vector2(1000.0, 0.0)
	root.add_child(nutrition_tank)
	assert(nutrition_tank.nutrition_per_second == 40.0)
	nutrition_tank.accepted_form_id = &"sprout"
	nutrition_tank.body_entered.emit(player)
	nutrition_tank._physics_process(1.0)
	assert(is_equal_approx(player.resources.growth_progress, 40.0))
	nutrition_tank._physics_process(2.0)
	assert(player.current_form_id() == &"humanoid")
	nutrition_tank._physics_process(5.0)
	assert(player.current_form_id() == &"humanoid")

	var wind_zone := preload("res://features/level/wind_zone.tscn").instantiate() as WindZone
	root.add_child(wind_zone)
	wind_zone.set_blowing_for_test(true)
	player.velocity.x = 0.0
	wind_zone.apply_to_actor(player, 0.5)
	assert(player.velocity.x > 0.0)
	for _step in 20:
		player.movement.tick(1.0 / 60.0, -1.0, false)
		wind_zone.apply_to_actor(player, 1.0 / 60.0)
	assert(player.velocity.x > 0.0)
	assert(player.form_controller.restore_form(&"humanoid"))
	await physics_frame
	player.velocity.x = 300.0
	assert(player.abilities.toggle_primary())
	assert(player.abilities.is_rooted())
	assert(player.velocity == Vector2.ZERO)
	wind_zone.apply_to_actor(player, 0.5)
	assert(player.velocity == Vector2.ZERO)
	assert(player.abilities.toggle_primary())
	assert(not player.abilities.is_rooted())

	var high_switch := preload("res://features/level/ability_switch.tscn").instantiate() as AbilitySwitch
	high_switch.position = Vector2(0.0, -200.0)
	root.add_child(high_switch)
	var gate := preload("res://features/level/whitebox_gate.tscn").instantiate() as WhiteboxGate
	gate.position = Vector2(300.0, 0.0)
	root.add_child(gate)
	gate.bind_switch(high_switch)
	assert(player.abilities.toggle_primary())
	player.abilities.set_leg_extension_direction(Vector2.UP)
	await physics_frame
	assert(not high_switch.is_active())
	assert(high_switch.try_activate_area(player.abilities.leg_area()))
	assert(high_switch.is_active())
	assert(not gate.is_closed())

	var low_switch := preload("res://features/level/ability_switch.tscn").instantiate() as AbilitySwitch
	low_switch.mode = AbilitySwitch.Mode.SPROUT_BODY
	root.add_child(low_switch)
	assert(not low_switch.try_activate_body(player))
	assert(player.form_controller.restore_form(&"sprout"))
	assert(low_switch.try_activate_body(player))

	var exit_goal := preload("res://features/level/exit_goal.tscn").instantiate() as ExitGoal
	root.add_child(exit_goal)
	var incomplete_switch := preload("res://features/level/ability_switch.tscn").instantiate() as AbilitySwitch
	root.add_child(incomplete_switch)
	exit_goal.set_required_switches([high_switch, incomplete_switch])
	var locked_count := [0]
	var completed_count := [0]
	exit_goal.locked_entered.connect(func(_actor: Player) -> void: locked_count[0] += 1)
	exit_goal.player_completed.connect(func(_actor: Player) -> void: completed_count[0] += 1)
	assert(not exit_goal.try_complete(player))
	assert(locked_count[0] == 1 and completed_count[0] == 0)
	incomplete_switch.activate_for_test()
	assert(exit_goal.try_complete(player))
	assert(completed_count[0] == 1)

	for node: Node in [
		player, ground, nutrition_tank, wind_zone, high_switch, gate,
		low_switch, incomplete_switch, exit_goal,
	]:
		node.free()
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
