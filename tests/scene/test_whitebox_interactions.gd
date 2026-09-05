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
	assert(is_zero_approx(player.resources.growth_progress))
	Input.action_press(&"absorb_resource")
	nutrition_tank._physics_process(1.0)
	assert(is_equal_approx(player.resources.growth_progress, 40.0))
	nutrition_tank._physics_process(2.0)
	assert(player.current_form_id() == &"humanoid")
	nutrition_tank._physics_process(5.0)
	assert(player.current_form_id() == &"humanoid")
	Input.action_release(&"absorb_resource")

	var toxin_zone := preload("res://features/level/toxin_zone.tscn").instantiate() as ToxinZone
	root.add_child(toxin_zone)
	toxin_zone.actor_entered.connect(func(actor: Node2D) -> void: actor.enter_toxin(toxin_zone))
	toxin_zone.actor_exited.connect(func(actor: Node2D) -> void: actor.exit_toxin(toxin_zone))
	toxin_zone.body_entered.emit(player)
	toxin_zone._physics_process(1.0)
	player.resources.tick(1.0)
	assert(is_equal_approx(player.resources.stability, 65.0))
	Input.action_press(&"absorb_resource")
	toxin_zone._physics_process(1.0)
	player.resources.tick(1.0)
	assert(is_equal_approx(player.resources.stability, 30.0))
	Input.action_release(&"absorb_resource")
	toxin_zone.body_exited.emit(player)
	player.resources.tick(0.1)
	assert(player.resources.stability > 30.0)

	var wind_zone := preload("res://features/level/wind_zone.tscn").instantiate() as WindZone
	wind_zone.position = Vector2(-180.0, -70.0)
	root.add_child(wind_zone)
	player.velocity.x = 0.0
	wind_zone.apply_to_actor(player, 0.5)
	assert(player.velocity.x < 0.0)
	for _step in 20:
		player.movement.tick(1.0 / 60.0, 1.0, false)
		wind_zone.apply_to_actor(player, 1.0 / 60.0)
	assert(player.velocity.x < 0.0)
	var wind_wall := StaticBody2D.new()
	wind_wall.collision_layer = 1
	var wind_wall_shape := CollisionShape2D.new()
	var wind_wall_rect := RectangleShape2D.new()
	wind_wall_rect.size = Vector2(16.0, 160.0)
	wind_wall_shape.shape = wind_wall_rect
	wind_wall.add_child(wind_wall_shape)
	wind_wall.position = Vector2(96.0, -1.0)
	root.add_child(wind_wall)
	player.velocity.x = 0.0
	wind_zone.apply_to_actor(player, 0.5)
	assert(is_zero_approx(player.velocity.x))
	wind_wall.free()
	await physics_frame
	var partial_wind_wall := StaticBody2D.new()
	partial_wind_wall.collision_layer = 1
	var partial_wall_shape := CollisionShape2D.new()
	var partial_wall_rect := RectangleShape2D.new()
	partial_wall_rect.size = Vector2(16.0, 32.0)
	partial_wall_shape.shape = partial_wall_rect
	partial_wind_wall.add_child(partial_wall_shape)
	partial_wind_wall.position = Vector2(96.0, 0.0)
	root.add_child(partial_wind_wall)
	player.global_position = Vector2(0.0, 0.0)
	player.velocity = Vector2.ZERO
	wind_zone.apply_to_actor(player, 0.5)
	assert(is_zero_approx(player.velocity.x), "A wall must block wind only at its occupied height.")
	player.global_position = Vector2(0.0, 48.0)
	player.velocity = Vector2.ZERO
	wind_zone.apply_to_actor(player, 0.5)
	assert(player.velocity.x < 0.0, "Wind must flow through an unblocked height beside a partial wall.")
	partial_wind_wall.free()
	await physics_frame
	var source_edge_wall := StaticBody2D.new()
	source_edge_wall.collision_layer = 1
	var source_edge_shape := CollisionShape2D.new()
	var source_edge_rect := RectangleShape2D.new()
	source_edge_rect.size = Vector2(16.0, 160.0)
	source_edge_shape.shape = source_edge_rect
	source_edge_wall.add_child(source_edge_shape)
	source_edge_wall.position = Vector2(182.0, 0.0)
	root.add_child(source_edge_wall)
	player.global_position = Vector2(0.0, 0.0)
	player.velocity = Vector2.ZERO
	wind_zone.apply_to_actor(player, 0.5)
	assert(is_zero_approx(player.velocity.x), "A wall overlapping the wind source boundary must not leak wind.")
	source_edge_wall.free()
	await physics_frame
	player.global_position = Vector2(0.0, -1.0)
	player.velocity = Vector2.ZERO
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
	assert(player.form_controller.restore_form(&"mature"))
	player.global_position = Vector2(0.0, -1.0)
	player.velocity = Vector2(0.0, 100.0)
	Input.action_press(&"jump")
	wind_zone.apply_to_actor(player, 0.1)
	Input.action_release(&"jump")
	assert(player.velocity.x > -180.0 and player.velocity.x < 0.0, "Mature leaves must reduce wind while gliding.")
	assert(player.form_controller.restore_form(&"humanoid"))
	var hard_floor := preload("res://features/level/rootable_surface.tscn").instantiate() as StaticBody2D
	hard_floor.set(&"allows_rooting", false)
	hard_floor.global_position = Vector2(600.0, 10.0)
	var hard_floor_collision := hard_floor.get_node("CollisionShape2D") as CollisionShape2D
	var hard_floor_shape := hard_floor_collision.shape as RectangleShape2D
	hard_floor_shape.size = Vector2(200.0, 20.0)
	root.add_child(hard_floor)
	player.global_position = Vector2(600.0, -1.0)
	player.velocity = Vector2.ZERO
	await _physics_steps(6)
	assert(not player.abilities.try_root())
	player.global_position = Vector2(0.0, -1.0)
	player.velocity = Vector2.ZERO
	await _physics_steps(6)

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
		player, ground, nutrition_tank, toxin_zone, wind_zone, hard_floor, high_switch, gate,
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
