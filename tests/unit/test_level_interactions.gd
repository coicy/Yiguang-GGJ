extends SceneTree


class NutritionActor extends Node2D:
	var absorbed_amount: float = 0.0

	func absorb_nutrition(amount: float) -> bool:
		absorbed_amount += amount
		return true


func _init() -> void:
	_test_toxin_zone_tracks_entering_and_exiting_actor()
	_test_hazard_reports_killed_actor()
	_test_checkpoint_activates_once_at_its_global_position()
	_test_nutrition_tank_uses_actor_absorption_contract()
	quit()


func _test_toxin_zone_tracks_entering_and_exiting_actor() -> void:
	var toxin_zone := ToxinZone.new()
	var actor := Node2D.new()
	var entered_actor: Node2D
	var exited_actor: Node2D

	root.add_child(toxin_zone)
	toxin_zone.actor_entered.connect(func(reported_actor: Node2D) -> void: entered_actor = reported_actor)
	toxin_zone.actor_exited.connect(func(reported_actor: Node2D) -> void: exited_actor = reported_actor)

	toxin_zone.body_entered.emit(actor)
	assert(toxin_zone.is_actor_inside(actor))
	assert(entered_actor == actor)

	toxin_zone.body_exited.emit(actor)
	assert(not toxin_zone.is_actor_inside(actor))
	assert(exited_actor == actor)

	toxin_zone.queue_free()
	actor.queue_free()


func _test_hazard_reports_killed_actor() -> void:
	var hazard := Hazard.new()
	var actor := Node2D.new()
	var killed_actor: Node2D

	hazard.actor_killed.connect(func(reported_actor: Node2D) -> void: killed_actor = reported_actor)
	hazard.kill(actor)

	assert(killed_actor == actor)


func _test_checkpoint_activates_once_at_its_global_position() -> void:
	var checkpoint := Checkpoint.new()
	var actor := Node2D.new()
	var reached_position := Vector2.INF

	checkpoint.position = Vector2(64.0, 32.0)
	checkpoint.checkpoint_reached.connect(func(reported_position: Vector2) -> void: reached_position = reported_position)

	assert(checkpoint.get_checkpoint_position() == Vector2(64.0, 32.0))
	assert(checkpoint.activate(actor))
	assert(reached_position == Vector2(64.0, 32.0))
	assert(not checkpoint.activate(actor))


func _test_nutrition_tank_uses_actor_absorption_contract() -> void:
	var nutrition_tank := NutritionTank.new()
	var actor := NutritionActor.new()

	assert(not nutrition_tank.absorb(Node.new(), 1.0))
	assert(nutrition_tank.absorb(actor, 1.5))
	assert(actor.absorbed_amount == 1.5)
