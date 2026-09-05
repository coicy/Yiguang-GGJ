extends "res://tests/scene/test_combat_system.gd"
## Repeated production AI fights with a deterministic evasive controller.
## This is automation evidence, not a human playtest or first-play timing claim.
var _shots: Array[SporeProjectile] = []

func _run() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	_add_solid(Vector2(0.0, 120.0), Vector2(1000.0, 40.0))
	_add_solid(Vector2(-370.0, -50.0), Vector2(20.0, 300.0))
	_add_solid(Vector2(370.0, -50.0), Vector2(20.0, 300.0))
	_player = PLAYER.instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	for form: StringName in [&"humanoid", &"mature"]:
		await _fight_elite(form)
	_world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: both forms defeated the production elite without using parry")
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _fight_elite(form: StringName) -> void:
	await _place(form)
	_player.position.x = -130.0
	var warden := _spawn(WARDEN, Vector2.ZERO + Vector2(0.0, 100.0))
	warden.target = _player
	warden.awake = true
	warden.bounds = Rect2(-360.0, -500.0, 720.0, 800.0)
	warden.projectile_requested.connect(_on_projectile)
	var frames := 0
	var saw_phase_two := false
	var damage_taken := 0
	var last_health := 5
	while frames < 12000 and warden.state != &"dead" and _player.combat.health.current > 0:
		await physics_frame
		var delta_x := warden.position.x - _player.position.x
		var toward := signf(delta_x)
		var distance := absf(delta_x)
		var danger := warden.state in [&"windup", &"strike"]
		var direction := 0.0
		if danger:
			var safe_x := clampf(warden.position.x - warden.facing * 60.0, -330.0, 330.0)
			if absf(safe_x - _player.position.x) > 10.0:
				direction = signf(safe_x - _player.position.x)
			var in_front := (_player.position.x - warden.position.x) * warden.facing >= 0.0
			if in_front and distance < 95.0 and _player.combat.dash_cooldown_left <= 0.0:
				_player.combat.request_action(&"dash", _player.position + Vector2(direction * 300.0, 0.0))
		else:
			if distance > 43.0:
				direction = toward
			elif _player.combat.state == &"idle":
				_player.combat.request_action(&"heavy", warden.position)
		_player.combat.tick(STEP)
		if warden.attack_kind == &"slam" and warden.state == &"windup" and warden.elapsed > 0.64:
			_player.movement.request_jump()
		for shot: Variant in _shots:
			if is_instance_valid(shot) and shot.shockwave and absf(shot.position.x - _player.position.x) < 95.0:
				_player.movement.request_jump()
		_player.movement.tick(STEP, direction, false)
		_player.combat.after_movement()
		warden._physics_process(STEP)
		for index: int in range(_shots.size() - 1, -1, -1):
			if not is_instance_valid(_shots[index]):
				_shots.remove_at(index)
			elif not _shots[index].is_queued_for_deletion():
				_shots[index]._physics_process(STEP)
		saw_phase_two = saw_phase_two or warden.second_phase
		if _player.combat.health.current < last_health:
			damage_taken += last_health - _player.combat.health.current
			last_health = _player.combat.health.current
		frames += 1
	_expect(warden.state == &"dead", "%s bot must defeat elite without parry (elite HP %d, player HP %d)" % [form, warden.health.current, _player.combat.health.current])
	_expect(saw_phase_two, "%s bot encounters the elite's second phase" % form)
	print("MEASURE elite %s: %.2f seconds, damage taken %d, remaining player HP %d, elite HP %d" % [form, frames * STEP, damage_taken, _player.combat.health.current, warden.health.current])
	for shot: Variant in _shots:
		if is_instance_valid(shot):
			shot.queue_free()
	_shots.clear()
	await _clear_enemies()

func _on_projectile(enemy: CombatEnemy, point: Vector2, direction: Vector2, wave: bool) -> void:
	var shot := SporeProjectile.new()
	shot.position = point
	shot.direction = direction
	shot.shockwave = wave
	shot.shooter = weakref(enemy)
	shot.speed = 210.0 if wave else 155.0
	_world.add_child(shot)
	shot.set_physics_process(false)
	_shots.append(shot)
