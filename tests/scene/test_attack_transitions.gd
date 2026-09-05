extends SceneTree
## Attack/movement contracts on shipped Player instances and non-playable collision fixtures.
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const BEETLE: PackedScene = preload("res://features/enemies/beetle.tscn")
const STEP: float = 1.0 / 60.0
var _world: Node2D
var _actor: Player
var _reference: Player
var _checks: int = 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	_solid(Vector2(0.0, 120.0), Vector2(8000.0, 40.0))
	_solid(Vector2(6000.0, 120.0), Vector2(80.0, 40.0))
	_actor = PLAYER.instantiate() as Player
	_reference = PLAYER.instantiate() as Player
	_world.add_child(_actor)
	_world.add_child(_reference)
	_actor.set_physics_process(false)
	_reference.set_physics_process(false)
	for form: StringName in [&"humanoid", &"mature"]:
		await _test_running_ground_attack(form)
		await _test_air_trajectory_and_inertia(form)
		await _test_landing_recovery(form)
		await _test_edge_transition(form)
		await _test_jump_and_attack_same_tick(form)
		await _test_recovery_jump_buffer(form)
	_release_inputs()
	_world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: %d attack transition assertions: two forms, ground braking, resume, facing lock, air inertia/vertical trajectory, landing recovery, ledge and same-tick jump" % _checks)
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _test_running_ground_attack(form: StringName) -> void:
	for action: StringName in [&"attack", &"heavy"]:
		await _place(_actor, form, Vector2.ZERO)
		for tick: int in range(20):
			await _step(1.0)
		var starting_speed: float = _actor.velocity.x
		var starting_x: float = _actor.position.x
		_expect(starting_speed > 0.95 * _actor.movement.form.move_speed, "%s %s starts from full running speed" % [form, action])
		_actor.combat.request_action(action, _actor.global_position + Vector2.RIGHT * 300.0)
		await _step(1.0)
		_expect(_actor.combat.attack != null and _actor.combat.attack.id != &"air", "%s %s starts a grounded strike" % [form, action])
		_expect(_actor.velocity.x >= 0.0 and _actor.velocity.x < starting_speed, "%s %s begins braking immediately" % [form, action])
		if _actor.combat.attack == null:
			continue
		var duration: float = _actor.combat.attack.duration() * _actor.combat.time_scale_for_form()
		var startup: float = _actor.combat.attack.windup * _actor.combat.time_scale_for_form()
		var stopped_x: float = INF
		var previous_speed: float = _actor.velocity.x
		for tick: int in range(70):
			if _actor.combat.state != &"attack":
				break
			if _actor.combat.elapsed >= startup:
				_expect(absf(_actor.velocity.x) <= 0.01, "%s %s plants feet before active frames" % [form, action])
				_expect(_actor.visuals.animation_machine.current_animation_state() == &"idle", "%s %s stops the walking feet with physical braking" % [form, action])
				if is_inf(stopped_x):
					stopped_x = _actor.position.x
				_expect(absf(_actor.position.x - stopped_x) < 0.05, "%s %s does not slide while striking" % [form, action])
			_expect(_actor.combat.facing == 1.0, "%s %s reverse input cannot turn the active attack" % [form, action])
			_expect(absf(_actor.velocity.x) <= previous_speed + 0.01, "%s %s holding direction cannot reaccelerate the attack" % [form, action])
			previous_speed = absf(_actor.velocity.x)
			await _step(-1.0 if _actor.combat.elapsed >= startup else 1.0)
		_expect(_actor.position.x - starting_x < starting_speed * minf(duration, 0.12), "%s %s braking stays within a short step" % [form, action])
		for tick: int in range(12):
			await _step(1.0)
		_expect(_actor.velocity.x > _actor.movement.form.move_speed * 0.75 and _actor.current_state() == &"run", "%s %s held movement resumes after recovery" % [form, action])

func _test_air_trajectory_and_inertia(form: StringName) -> void:
	await _place(_actor, form, Vector2.ZERO)
	await _place(_reference, form, Vector2(600.0, 0.0))
	_actor.position = Vector2(0.0, -250.0)
	_reference.position = Vector2(600.0, -250.0)
	var entry_speed: float = _actor.movement.form.move_speed
	_actor.velocity = Vector2(entry_speed, -320.0)
	_reference.velocity = Vector2(entry_speed, -320.0)
	_actor.state_machine.tick(STEP, 1.0, false)
	_reference.state_machine.tick(STEP, 1.0, false)
	_actor.combat.request_action(&"attack", _actor.global_position + Vector2.RIGHT * 300.0)
	for tick: int in range(12):
		await physics_frame
		_actor.combat.tick(STEP)
		_actor.state_machine.tick(STEP, 0.0 if tick < 5 else -1.0, false)
		_actor.combat.after_movement()
		_reference.combat.tick(STEP)
		_reference.state_machine.tick(STEP, 0.0, false)
		_reference.combat.after_movement()
		_expect(absf(_actor.position.y - _reference.position.y) < 0.01 and absf(_actor.velocity.y - _reference.velocity.y) < 0.01, "%s air attack preserves the unmodified jump trajectory" % form)
		if tick == 0:
			_expect(_actor.combat.attack != null and _actor.combat.attack.id == &"air", "%s moving airborne input selects air attack" % form)
			_expect(_actor.velocity.x >= entry_speed * 0.8, "%s entering air attack preserves horizontal inertia" % form)
		if tick == 4:
			_expect(_actor.velocity.x >= entry_speed * 0.65, "%s releasing direction during air attack does not apply ground braking" % form)
		if tick == 5:
			_expect(_actor.velocity.x > 0.0, "%s reversing midair cannot snap horizontal velocity" % form)
		_expect(_actor.combat.facing == 1.0, "%s air steering does not reverse the attack facing" % form)
	for tick: int in range(30):
		await _step(0.0)
		if _actor.combat.state == &"idle":
			break
	_actor.combat.request_action(&"attack", _actor.global_position + Vector2.LEFT * 300.0)
	await _step()
	_expect(not _actor.is_on_floor() and _actor.combat.attack == null, "%s finishing or steering an air attack does not grant a second aerial strike" % form)

func _test_landing_recovery(form: StringName) -> void:
	await _place(_actor, form, Vector2.ZERO)
	_actor.position.y = 84.0
	_actor.velocity = Vector2(0.0, 150.0)
	_actor.state_machine.tick(STEP, 0.0, false)
	_actor.combat.request_action(&"attack", _actor.global_position + Vector2.RIGHT * 300.0)
	var landed: bool = false
	for tick: int in range(18):
		await _step(1.0)
		if _actor.is_on_floor():
			landed = true
			break
	_expect(landed and _actor.combat.state == &"attack_landing", "%s air contact with floor enters brief attack_landing" % form)
	_expect(_actor.visuals.animation_machine.current_animation_state() == &"jump_end", "%s landing uses the existing planted-foot landing clip" % form)
	_expect(_actor.combat.attack != null and _actor.combat.attack.id == &"air", "%s landing keeps only the air definition needed for harmless retraction" % form)
	await _assert_landing_has_no_damage(form)
	var visual: VineWhipVisual = _actor.visuals.find_child("VineWhipVisual", true, false) as VineWhipVisual
	if visual != null:
		_expect(visual.tip_position.is_finite(), "%s landing keeps a finite visual-only retraction" % form)
	for tick: int in range(3):
		await _step(1.0)
		_expect(_actor.combat.state == &"attack_landing", "%s landing recovery cannot re-open the air hit" % form)
	for tick: int in range(4):
		await _step(1.0)
	_expect(_actor.combat.state == &"idle" and _actor.velocity.x > 0.0, "%s landing recovery finishes around 0.08s and resumes movement" % form)
	if visual != null:
		_expect(not visual.visible, "%s short landing retraction ends without a residual vine" % form)

func _assert_landing_has_no_damage(form: StringName) -> void:
	var enemy := BEETLE.instantiate() as CombatEnemy
	enemy.position = _actor.position + Vector2(30.0, 0.0)
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	var initial_health: int = enemy.health.current
	var saved_elapsed: float = _actor.combat.elapsed
	# A stale active-window clock cannot make a landing pose deal damage.
	if _actor.combat.attack != null:
		_actor.combat.elapsed = (_actor.combat.attack.windup + _actor.combat.attack.active * 0.5) * _actor.combat.time_scale_for_form()
	_actor.combat.after_movement()
	_expect(enemy.health.current == initial_health, "%s landing state blocks real Hurtbox damage even with an active-window clock" % form)
	_actor.combat.elapsed = saved_elapsed
	enemy.queue_free()
	await process_frame

func _test_edge_transition(form: StringName) -> void:
	var radius: float = _actor.form_controller.get_current().collision_size.x * 0.5
	await _place(_actor, form, Vector2(6040.0 + radius * 0.4, 0.0))
	_actor.velocity.x = _actor.movement.form.move_speed
	_actor.combat.request_action(&"heavy", _actor.global_position + Vector2.RIGHT * 300.0)
	var left_floor: bool = false
	for tick: int in range(24):
		await _step(1.0)
		if not _actor.is_on_floor():
			left_floor = true
			break
	_expect(left_floor, "%s edge fixture crosses the platform while braking" % form)
	_expect(_actor.combat.attack == null and _actor.combat.state != &"attack", "%s grounded attack stops when support is lost" % form)
	_expect(_actor.current_state() in [&"fall", &"jump"], "%s leaving the ledge restores airborne locomotion" % form)

func _test_jump_and_attack_same_tick(form: StringName) -> void:
	await _place(_actor, form, Vector2.ZERO)
	_release_inputs()
	await process_frame
	_actor.set_physics_process(true)
	var jump_event := InputEventAction.new()
	jump_event.action = &"jump"
	jump_event.pressed = true
	Input.parse_input_event(jump_event)
	_actor.combat.request_action(&"attack", _actor.global_position + Vector2.RIGHT * 300.0)
	await physics_frame
	await process_frame
	_expect(_actor.velocity.y < -100.0 and not _actor.is_on_floor(), "%s same-tick jump plus attack keeps the requested jump" % form)
	await physics_frame
	await process_frame
	_expect(_actor.combat.attack != null and _actor.combat.attack.id == &"air", "%s jump plus attack starts its buffered air strike on the next physics tick" % form)
	_actor.set_physics_process(false)
	Input.action_release(&"jump")
	await process_frame

func _test_recovery_jump_buffer(form: StringName) -> void:
	await _place(_actor, form, Vector2.ZERO)
	await process_frame
	_actor.set_physics_process(true)
	_actor.combat.request_action(&"heavy", _actor.global_position + Vector2.RIGHT * 300.0)
	for tick: int in range(70):
		await physics_frame
		await process_frame
		if _actor.combat.attack != null and _actor.combat.elapsed >= _actor.combat.attack.duration() * _actor.combat.time_scale_for_form() - 0.075:
			break
	var jump_event := InputEventAction.new()
	jump_event.action = &"jump"
	jump_event.pressed = true
	Input.parse_input_event(jump_event)
	await physics_frame
	await process_frame
	_expect(_actor.is_on_floor() and _actor.movement.has_buffered_jump(), "%s jump pressed near recovery end stays buffered while feet remain planted" % form)
	for tick: int in range(12):
		await physics_frame
		await process_frame
		if not _actor.is_on_floor():
			break
	_expect(not _actor.is_on_floor() and _actor.velocity.y < -100.0 and _actor.combat.state == &"idle", "%s recovery consumes buffered jump once the attack ends" % form)
	_actor.set_physics_process(false)
	Input.action_release(&"jump")
	await process_frame

func _place(player: Player, form: StringName, offset: Vector2) -> void:
	_release_inputs()
	player.cancel_actions()
	player.movement.set_movement_locked(true)
	player.movement.set_movement_locked(false)
	player.combat.reset()
	player.revive_animation()
	player.form_controller.restore_form(form)
	player.position = offset + Vector2(0.0, 65.0)
	player.velocity = Vector2.ZERO
	for tick: int in range(40):
		await physics_frame
		player.combat.tick(STEP)
		player.state_machine.tick(STEP, 0.0, false)
		player.combat.after_movement()
		player.visuals.set_combat_state(player.combat)
		if player.is_on_floor():
			break
	_expect(player.is_on_floor(), "%s fixture begins grounded offset=%s actual=%s" % [form, offset, player.position])

func _step(direction: float = 0.0) -> void:
	await physics_frame
	_actor.combat.tick(STEP)
	_actor.state_machine.tick(STEP, direction, false)
	_actor.combat.after_movement()
	_actor.visuals.set_combat_state(_actor.combat)
	_actor.visuals.set_motion(_actor.velocity)

func _solid(location: Vector2, size: Vector2) -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = location
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	_world.add_child(floor_body)

func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
