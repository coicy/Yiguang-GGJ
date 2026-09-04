extends SceneTree


class NutritionActor extends Node2D:
	var absorbed_amount: float = 0.0

	func absorb_nutrition(amount: float) -> bool:
		absorbed_amount += amount
		return true


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await _test_toxin_zone_tracks_physical_entry_and_exit()
	await _test_hazard_reports_hurt_before_killed_on_physical_entry()
	await _test_checkpoint_activates_once_on_physical_entry()
	_test_nutrition_tank_uses_actor_absorption_contract()
	quit()


func _test_toxin_zone_tracks_physical_entry_and_exit() -> void:
	var toxin_zone := ToxinZone.new()
	var actor := _create_physics_actor()
	var entered_actors: Array[Node2D] = []
	var exited_actors: Array[Node2D] = []

	_configure_area(toxin_zone, Vector2(128.0, 64.0), 64)
	root.add_child(toxin_zone)
	toxin_zone.actor_entered.connect(func(reported_actor: Node2D) -> void: entered_actors.append(reported_actor))
	toxin_zone.actor_exited.connect(func(reported_actor: Node2D) -> void: exited_actors.append(reported_actor))

	actor.position = Vector2(256.0, 0.0)
	root.add_child(actor)
	await _await_collision_update()
	actor.position = Vector2.ZERO
	await _await_collision_update()
	assert(toxin_zone.is_actor_inside(actor))
	assert(entered_actors == [actor])

	actor.position = Vector2(256.0, 0.0)
	await _await_collision_update()
	assert(not toxin_zone.is_actor_inside(actor))
	assert(exited_actors == [actor])

	_free_nodes([actor, toxin_zone])


func _test_hazard_reports_hurt_before_killed_on_physical_entry() -> void:
	var hazard := Hazard.new()
	var actor := _create_physics_actor()
	var reported_events: Array[StringName] = []

	_configure_area(hazard, Vector2(128.0, 32.0), 32)
	hazard.position = Vector2(1024.0, 0.0)
	root.add_child(hazard)
	hazard.actor_hurt.connect(func(reported_actor: Node2D) -> void:
		assert(reported_actor == actor)
		reported_events.append(&"hurt")
	)
	hazard.actor_killed.connect(func(reported_actor: Node2D) -> void:
		assert(reported_actor == actor)
		reported_events.append(&"killed")
	)

	actor.position = Vector2(1280.0, 0.0)
	root.add_child(actor)
	await _await_collision_update()
	actor.position = hazard.position
	await _await_collision_update()
	assert(reported_events == [&"hurt", &"killed"])

	_free_nodes([actor, hazard])


func _test_checkpoint_activates_once_on_physical_entry() -> void:
	var checkpoint := Checkpoint.new()
	var actor := _create_physics_actor()
	var reached_positions: Array[Vector2] = []

	checkpoint.position = Vector2(2048.0, 32.0)
	_configure_area(checkpoint, Vector2(48.0, 64.0), 64)
	root.add_child(checkpoint)
	checkpoint.checkpoint_reached.connect(func(reported_position: Vector2) -> void: reached_positions.append(reported_position))

	actor.global_position = Vector2(1792.0, 32.0)
	root.add_child(actor)
	await _await_collision_update()
	actor.global_position = checkpoint.global_position
	await _await_collision_update()
	assert(checkpoint.get_checkpoint_position() == Vector2(2048.0, 32.0))
	assert(reached_positions == [Vector2(2048.0, 32.0)])
	assert(not checkpoint.activate(actor))

	_free_nodes([actor, checkpoint])


func _test_nutrition_tank_uses_actor_absorption_contract() -> void:
	var nutrition_tank := NutritionTank.new()
	var actor := NutritionActor.new()

	var invalid_actor := Node.new()
	assert(not nutrition_tank.absorb(invalid_actor, 1.0))
	assert(nutrition_tank.absorb(actor, 1.5))
	assert(actor.absorbed_amount == 1.5)
	_free_nodes([nutrition_tank, invalid_actor, actor])


func _create_physics_actor() -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	actor.collision_layer = 2
	actor.collision_mask = 64
	_add_collision_shape(actor, Vector2(16.0, 16.0))
	return actor


func _configure_area(area: Area2D, shape_size: Vector2, collision_layer: int) -> void:
	area.collision_layer = collision_layer
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = true
	_add_collision_shape(area, shape_size)


func _add_collision_shape(node: CollisionObject2D, shape_size: Vector2) -> void:
	var collision_shape := CollisionShape2D.new()
	var rectangle_shape := RectangleShape2D.new()
	rectangle_shape.size = shape_size
	collision_shape.shape = rectangle_shape
	node.add_child(collision_shape)


func _free_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.free()


func _await_physics_step() -> void:
	await physics_frame
	await process_frame


func _await_collision_update() -> void:
	await _await_physics_step()
	await _await_physics_step()
	await _await_physics_step()
