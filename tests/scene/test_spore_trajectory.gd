extends "res://tests/scene/test_spore_behavior.gd"
## Production projectile flight and animated nozzle alignment, on both sides/elevations.
func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_solid(Vector2(0, 110), Vector2(1200, 20))
	player = PLAYER.instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	for form: StringName in [&"humanoid", &"mature"]:
		player.form_controller.restore_form(form)
		for face: float in [-1.0, 1.0]:
			for distance: float in [95.0, 330.0]:
				for height: float in [-45.0, 0.0]:
					await _verify_shot(face, distance, height)
	world.queue_free()
	await process_frame
	print("SPORE TRAJECTORY: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _verify_shot(face: float, distance: float, height: float) -> void:
	await _spawn(distance * face, face)
	player.position.y += height
	enemy.spore_behavior._begin_attack(&"spit")
	enemy.elapsed = enemy.spore_behavior.tuning.spit_windup - enemy.spore_behavior.tuning.aim_lock_before_release
	await _step()
	var locked_point: Vector2 = player.hurtbox.world_center()
	_expect(enemy.spore_behavior.aim_point.is_equal_approx(locked_point), "Lock uses the current form's actual hurtbox center")
	# Dodge after lock. A straight shot should continue toward the previously shown point.
	player.position = Vector2(-face * 450, -100)
	enemy._set_state(&"strike")
	enemy.elapsed = enemy.spore_behavior.tuning.spit_release - STEP * 0.5
	await _step()
	_expect(shots.size() == 1, "Exactly one shot leaves the mouth")
	if shots.is_empty():
		return
	var origin: Vector2 = shots[0].point
	var axis: Vector2 = shots[0].direction
	var to_target: Vector2 = locked_point - origin
	_expect(absf(axis.length() - 1.0) < 0.0001, "Launch direction has unit length")
	_expect(absf(to_target.cross(axis)) < 0.001 and to_target.dot(axis) > 0, "Launch ray crosses the locked target point from the actual muzzle")
	var visual_axis: Vector2 = (enemy.visuals as SporeVisual).pose_snapshot().muzzle_direction
	_expect(visual_axis.dot(axis) > 0.99999, "Painted nozzle axis matches flight despite body squash/rotation")
	var shot := SporeProjectile.new()
	shot.position = origin
	shot.direction = axis
	shot.shooter = weakref(enemy)
	world.add_child(shot)
	shot.set_physics_process(false)
	for tick: int in range(30):
		await physics_frame
		player.position.x += face * 4.0
		shot._physics_process(STEP)
		var expected: Vector2 = origin + axis * shot.speed * STEP * (tick + 1)
		_expect(shot.position.distance_to(expected) < 0.002, "Every flight sample stays on the constant-speed straight trajectory")
		_expect(shot.direction.is_equal_approx(axis), "Player motion cannot bend an emitted shot")
	shot.receive_parry(player)
	var reflected_axis: Vector2 = shot.direction
	var reflected_start: Vector2 = shot.position
	for tick: int in range(8):
		await physics_frame
		shot._physics_process(STEP)
		_expect(shot.position.distance_to(reflected_start + reflected_axis * 260.0 * STEP * (tick + 1)) < 0.002, "Reflected projectile also keeps one straight return path")
	shot.queue_free()
	await process_frame
