extends SceneTree
## Deterministic physics contracts using the shipped player and enemy scenes.
## This script creates collision fixtures, never a separate playable test level.
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const BEETLE: PackedScene = preload("res://features/enemies/beetle.tscn")
const SPORE: PackedScene = preload("res://features/enemies/spore.tscn")
const PRUNER: PackedScene = preload("res://features/enemies/pruner.tscn")
const WARDEN: PackedScene = preload("res://features/enemies/warden.tscn")
const STEP: float = 1.0 / 60.0
var _world: Node2D
var _player: Player
var _enemies: Array[CombatEnemy] = []
var _failures: PackedStringArray = []
var _checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	_add_solid(Vector2(0.0, 120.0), Vector2(3000.0, 40.0))
	_player = PLAYER.instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_test_health()
	await _test_sprout_and_abilities()
	await _test_sprout_bump()
	for form: StringName in [&"humanoid", &"mature"]:
		await _test_combo(form)
		await _test_cancel_windows(form)
		await _test_air_limits(form)
		await _test_hits_and_guard(form)
		await _test_dash_and_parry(form)
		await _test_parry_choreography(form)
		await _test_parry_feedback(form)
		await _test_warden_contracts(form)
	await _test_wall_queries()
	await _test_projectiles()
	await _test_recovery_reset()
	_world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: %d combat assertions: both forms, combo timing, cancellation, hit deduplication, guard, dash, parry, elite and projectile walls" % _checks)
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _test_health() -> void:
	var health := HealthComponent.new()
	health.reset_health()
	var deaths: Array[int] = [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	var hit := DamageRequest.new()
	_expect(health.take_damage(hit) and health.current == 4, "Damage reduces only the receiving health")
	_expect(not health.take_damage(hit) and health.current == 4, "Protection prevents consecutive frame damage")
	health.tick(0.8)
	hit.amount = 9
	_expect(health.take_damage(hit) and health.current == 0 and deaths[0] == 1, "Lethal damage clamps at zero and emits one death")
	_expect(not health.take_damage(hit) and deaths[0] == 1, "A dead actor cannot die repeatedly")
	health.reset_health()
	_expect(health.current == 5 and is_zero_approx(health.protection_left), "Health reset clears protection")
	health.free()

func _test_sprout_and_abilities() -> void:
	await _place(&"sprout")
	for action: StringName in [&"heavy", &"dash", &"parry"]:
		_player.combat.request_action(action, Vector2(300.0, 0.0))
		await _step()
		_expect(_player.combat.state == &"idle", "Sprout must reject %s" % action)
	await _place(&"humanoid")
	_expect(_player.abilities.try_root(), "Fixture allows humanoid rooting")
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	_expect(not _player.abilities.is_rooted() and not _player.abilities.is_leg_extended(), "Attack exits rooted ability immediately")
	_expect(not _player.combat.can_use_ability(), "Ability input is gated throughout combat actions")
	_expect(_player.leg_area.collision_layer == 128, "Leg extension uses its separate mechanism layer")
	_player.form_controller.restore_form(&"mature")
	_expect(_player.combat.state == &"idle" and _player.combat.attack == null, "Form switch cancels active hit and input cache")

func _test_sprout_bump() -> void:
	for face: float in [-1.0, 1.0]:
		await _place(&"sprout")
		var combat := _player.combat
		combat.facing = face
		var initial := _player.position
		var enemy := _spawn(BEETLE, initial + Vector2(face * 30.0, 0.0))
		await physics_frame
		combat.request_action(&"attack", initial + Vector2(face * 300.0, 0.0))
		await _step()
		_expect(combat.attack != null and combat.attack.id == &"sprout_bump", "Sprout selects its own ground bump")
		_expect(not combat.can_use_ability(), "Bump gates absorption and abilities")
		while combat.elapsed < combat.attack.windup - STEP:
			await _step(-face)
		_expect(enemy.health.current == enemy.health.maximum and _player.position.distance_to(initial) < 0.1, "Bump anticipation has no damage or thrust")
		var last_bump_position := _player.position
		var attack_elapsed := combat.elapsed
		var attack_end_x := _player.position.x
		while combat.state == &"attack":
			await _step(-face)
			if combat.state == &"attack":
				_expect(combat.facing == face, "Bump facing stays locked against movement input")
				attack_elapsed = combat.elapsed
				last_bump_position = _player.position
				attack_end_x = _player.position.x
		_expect(enemy.health.current == enemy.health.maximum - 1, "Bump deals exactly one damage across its active window")
		_expect(absf((attack_end_x - initial.x) * face - 14.4) < 0.5, "Bump travels only half a body width")
		_expect(attack_elapsed >= 0.32, "Bump completes its recovery before returning control")
		_expect(_player.is_on_floor() and not _player.form_controller.current_form.can_jump, "Bump stays grounded and does not grant jumping")
		combat.request_action(&"attack", _player.position + Vector2(face * 300.0, 0.0))
		await _step()
		_expect(combat.attack != null and combat.attack.id == &"sprout_bump", "Repeated bump never advances to a vine combo")
		_player.form_controller.restore_form(&"humanoid")
		_expect(combat.state == &"idle" and combat.attack == null and not _player.movement._motion_override, "Growing cancels bump and its movement override")
		await _clear_enemies()
	await _place(&"sprout")
	var initial := _player.position
	var guard := _spawn(PRUNER, initial + Vector2(30.0, 0.0))
	guard.facing = -1.0
	await physics_frame
	_player.combat.request_action(&"attack", guard.position)
	for tick: int in range(25):
		await _step()
	_expect(guard.health.current == guard.health.maximum, "Small bump cannot break frontal guard")
	await _clear_enemies()
	await _place(&"sprout")
	initial = _player.position
	var wall := _add_solid(initial + Vector2(19.0, -20.0), Vector2(4.0, 60.0))
	var behind_wall := _spawn(BEETLE, initial + Vector2(30.0, 0.0))
	await physics_frame
	_player.combat.request_action(&"attack", behind_wall.position)
	for tick: int in range(25):
		await _step()
	_expect(_player.position.x - initial.x < 6.0, "Bump movement stops at a thin wall")
	_expect(behind_wall.health.current == behind_wall.health.maximum, "Bump cannot deal damage through a wall")
	wall.queue_free()
	await _clear_enemies()
	await _place(&"sprout")
	initial = _player.position
	var distant := _spawn(BEETLE, initial + Vector2(65.0, 0.0))
	var above := _spawn(BEETLE, initial + Vector2(24.0, -45.0))
	await physics_frame
	_player.combat.request_action(&"attack", distant.position)
	for tick: int in range(25):
		await _step()
	_expect(distant.health.current == distant.health.maximum and above.health.current == above.health.maximum, "Bump range stays short and at sprout body height")
	await _clear_enemies()
	await _place(&"sprout")
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	_player.position.y -= 100.0
	_player.velocity = Vector2.ZERO
	await _step()
	_expect(_player.combat.state == &"idle" and _player.combat.attack == null, "Losing floor support cancels the bump")
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	_expect(_player.combat.state == &"idle", "Falling sprout cannot start an air attack")
	await _place(&"sprout")
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	for tick: int in range(9):
		await _step()
	var hit := DamageRequest.new()
	hit.knockback = Vector2(-120.0, 0.0)
	_player.combat.receive_damage(hit)
	_expect(_player.combat.state == &"hurt" and _player.combat.attack == null, "Taking damage interrupts an active bump")
	_player.combat.reset()
	await _step()
	_expect(not _player.movement._motion_override and _player.combat.state == &"idle", "Reset removes bump impulse and returns movement")

func _test_combo(form: StringName) -> void:
	await _place(form)
	var combat := _player.combat
	combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.attack != null and combat.attack.id == &"light_1", "%s starts first light" % form)
	for next_index: int in range(2, 4):
		var duration := combat.attack.duration() * combat.time_scale_for_form()
		while combat.elapsed < duration - 0.09:
			await _step()
		var previous_attack := combat.attack
		var elapsed_before := combat.elapsed
		combat.request_action(&"attack", Vector2.RIGHT * 300.0)
		await _step(-1.0)
		_expect(combat.attack == previous_attack, "%s light recovery is not skipped by buffered attacks" % form)
		_expect(combat.facing == 1.0, "%s facing stays locked while moving left" % form)
		var ticks := 1
		while combat.attack == previous_attack and ticks < 30:
			await _step()
			ticks += 1
		_expect(elapsed_before + ticks * STEP >= duration, "%s chain respects configured full duration" % form)
		_expect(combat.attack != null and combat.attack.id == StringName("light_%d" % next_index), "%s buffers light %d" % [form, next_index])
	while combat.state != &"idle":
		await _step()
	for tick: int in range(16):
		await _step()
	combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.attack != null and combat.attack.id == &"light_1", "%s expired combo returns to first attack" % form)

func _test_cancel_windows(form: StringName) -> void:
	await _place(form)
	var combat := _player.combat
	combat.request_action(&"heavy", Vector2.RIGHT * 300.0)
	await _step()
	combat.request_action(&"dash", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.state == &"attack", "%s cannot cancel heavy startup" % form)
	while combat.elapsed < (combat.attack.windup + combat.attack.active) * combat.time_scale_for_form():
		await _step()
	combat.request_action(&"dash", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.state == &"dash" and combat.attack == null, "%s dash cancels heavy only after active frames" % form)
	_expect(not _player.movement.allow_jump and not _player.movement.allow_glide, "%s dash suppresses jump and glide" % form)
	await _place(form)
	combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	while combat.elapsed < (combat.attack.windup + combat.attack.active) * combat.time_scale_for_form():
		await _step()
	combat.request_action(&"parry", Vector2.LEFT * 300.0)
	await _step()
	_expect(combat.state == &"parry" and combat.facing == 1.0, "%s parry cancels light recovery without changing facing" % form)
	await _place(form)
	combat.set_facing(-1.0)
	combat.request_action(&"parry", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.state == &"parry" and combat.facing == -1.0, "%s parry keeps left facing when aim is on the opposite side" % form)

func _test_air_limits(form: StringName) -> void:
	await _place(form)
	_player.position = Vector2(0.0, -250.0)
	_player.velocity = Vector2.ZERO
	await _step()
	var combat := _player.combat
	combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.attack != null and combat.attack.id == &"air", "%s airborne light selects air attack" % form)
	_expect(_player.velocity.y >= 0.0, "%s air attack never creates upward impulse" % form)
	if form == &"mature":
		_expect(_player.state_machine._evaluate_target(0.0, true) != StateMachine.STATE_GLIDE, "Combat suppresses the glide locomotion state as well as glide physics")
	while combat.state != &"idle":
		await _step()
	combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.state == &"idle" and combat.air_attack_used, "%s cannot repeat air attacks without landing" % form)
	combat.cancel()
	combat.request_action(&"dash", Vector2.RIGHT * 300.0)
	await _step()
	while combat.state == &"dash":
		await _step()
	# Keep the physics fixture airborne while the regular cooldown expires.
	_player.position.y = -500.0
	while combat.dash_cooldown_left > 0.0:
		await _step()
	combat.request_action(&"dash", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.state == &"idle" and combat.air_dash_used, "%s air dash remains spent after cooldown" % form)
	await _place(form)
	_player.position = Vector2(0.0, 96.0)
	_player.velocity = Vector2(0.0, 10.0)
	await _step()
	# Lift enough to start an air strike and land during its startup.
	_player.position.y = 95.0
	_player.velocity.y = 40.0
	_player.movement.tick(STEP, 0.0, false)
	combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	for tick: int in range(8):
		await _step()
	_expect(_player.is_on_floor() and combat.state == &"idle" and combat.attack == null, "%s landing clears airborne attack and its stale hitbox" % form)
	_expect(not combat.air_dash_used and not combat.air_attack_used, "%s landing restores aerial actions" % form)

func _test_hits_and_guard(form: StringName) -> void:
	await _place(form)
	var first := _spawn(BEETLE, Vector2(38.0, 100.0))
	var second := _spawn(BEETLE, Vector2(500.0, 100.0))
	await physics_frame
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	for tick: int in range(20):
		await _step()
	_expect(is_equal_approx(first.poise.current, first.poise.maximum - 10.0), "One swing applies authored poise damage once")
	_expect(first.health.current == first.health.maximum - 1, "%s one swing damages a target exactly once" % form)
	_expect(second.health.current == second.health.maximum, "%s enemy health is not shared" % form)
	await _clear_enemies()
	await _place(form)
	var pruner := _spawn(PRUNER, Vector2(40.0, 100.0))
	pruner.facing = -1.0
	await physics_frame
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	for tick: int in range(30):
		await _step()
	_expect(pruner.health.current == pruner.health.maximum, "%s light strike respects frontal guard" % form)
	_player.combat.request_action(&"heavy", Vector2.RIGHT * 300.0)
	for tick: int in range(30):
		await _step()
	_expect(pruner.health.current == pruner.health.maximum - 3 and pruner.state == &"stun", "%s heavy breaks guard and applies three damage" % form)
	_player.combat.cancel()
	pruner.health.reset_health()
	pruner.state = &"idle"
	pruner.facing = 1.0
	pruner._guard_open = 0.0
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	for tick: int in range(20):
		await _step()
	_expect(pruner.health.current == pruner.health.maximum - 1, "%s rear attacks bypass frontal guard" % form)
	await _clear_enemies()

func _test_dash_and_parry(form: StringName) -> void:
	await _place(form)
	var combat := _player.combat
	var request := DamageRequest.new()
	request.origin = Vector2(50.0, 80.0)
	request.knockback = Vector2(-150.0, -70.0)
	combat.request_action(&"dash", Vector2.RIGHT * 300.0)
	await _step()
	await _step()
	await _step()
	_expect(combat.receive_damage(request) == DamageRequest.Result.IGNORED and combat.health.current == 5, "%s dash safe interval rejects damage" % form)
	while combat.state == &"dash":
		await _step()
	combat.request_action(&"dash", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.state == &"idle" and combat.dash_cooldown_left > 0.0, "%s dash enforces cooldown" % form)
	await _place(form)
	var attacker := _spawn(BEETLE, Vector2(55.0, 100.0))
	request.source = attacker
	combat.request_action(&"parry", Vector2.RIGHT * 300.0)
	await _step()
	await _step()
	await _step()
	_expect(combat.receive_damage(request) == DamageRequest.Result.PARRIED and combat.health.current == 5, "%s timed front parry protects health" % form)
	_expect(attacker.state == &"stun", "%s parry opens attacker for retaliation" % form)
	combat.request_action(&"heavy", Vector2.RIGHT * 300.0)
	await _step()
	_expect(combat.state == &"attack", "%s successful parry immediately permits counterattack" % form)
	await _place(form)
	combat.request_action(&"parry", Vector2.RIGHT * 300.0)
	await _step()
	await _step()
	await _step()
	request.origin = Vector2(-50.0, 80.0)
	var resources := _player.resources.snapshot()
	_expect(combat.receive_damage(request) == DamageRequest.Result.HIT and combat.health.current == 4, "%s parry does not cover the rear" % form)
	_expect(_player.current_form_id() == form and _player.resources.snapshot() == resources, "%s damage preserves growth resources and form" % form)
	await _place(form)
	combat.request_action(&"parry", Vector2.RIGHT * 300.0)
	await _step()
	await _step()
	await _step()
	request.origin = Vector2(50.0, 80.0)
	request.parryable = false
	request.amount = 2
	_expect(combat.receive_damage(request) == DamageRequest.Result.HIT and combat.health.current == 3, "%s uncounterable slam defeats parry" % form)
	await _clear_enemies()

func _test_warden_contracts(form: StringName) -> void:
	await _place(form)
	var warden := _spawn(WARDEN, Vector2(50.0, 100.0))
	warden.state = &"windup"
	await physics_frame
	_player.combat.request_action(&"heavy", Vector2.RIGHT * 300.0)
	for tick: int in range(30):
		await _step()
	_expect(warden.health.current == 37 and warden.state == &"windup", "%s attacks damage elite without interrupting its move" % form)
	var hit := DamageRequest.new()
	hit.source = _player
	hit.amount = 18
	hit.origin = Vector2.ZERO
	warden.receive_damage(hit)
	_expect(warden.second_phase, "%s elite enters second phase below half health" % form)
	var waves: Array[int] = [0]
	warden.projectile_requested.connect(func(_enemy: CombatEnemy, _position: Vector2, _direction: Vector2, wave: bool) -> void:
		if wave:
			waves[0] += 1
	)
	warden.target = _player
	warden.awake = true
	warden.velocity = Vector2.ZERO
	warden._set_state(&"idle")
	warden.warden_behavior.phase_pending = false
	for tick: int in range(3):
		await physics_frame
		warden._physics_process(STEP)
	warden.warden_behavior._begin_attack(&"slam")
	for tick: int in range(53):
		await physics_frame
		warden._physics_process(STEP)
	_expect(waves[0] == 0, "%s elite slam has no waves before actual ground impact" % form)
	for tick: int in range(8):
		await physics_frame
		warden._physics_process(STEP)
	for tick: int in range(5):
		warden.warden_behavior.after_movement()
	_expect(waves[0] == 2, "%s elite slam emits exactly two waves at impact, including repeated hitstop callbacks" % form)
	warden.receive_parry(_player)
	_expect(warden.state == &"stun" and is_equal_approx(warden.warden_behavior.stun_duration, 2.0), "%s elite parry grants a 2-second opening" % form)
	await _clear_enemies()

func _test_wall_queries() -> void:
	await _place(&"mature")
	var enemy := _spawn(BEETLE, Vector2(48.0, 100.0))
	var wall := _add_solid(Vector2(24.0, 50.0), Vector2(6.0, 100.0))
	await physics_frame
	_player.combat.request_action(&"heavy", Vector2.RIGHT * 300.0)
	for tick: int in range(45):
		await _step()
	_expect(enemy.health.current == enemy.health.maximum, "Melee does not hit an enemy through a thin wall")
	enemy.facing = -1.0
	enemy.state = &"strike"
	enemy.attack_kind = &"charge"
	enemy._deliver_strike()
	_expect(_player.combat.health.current == 5, "Enemy attacks cannot damage the player through a wall")
	_player.combat.request_action(&"dash", Vector2.RIGHT * 300.0)
	for tick: int in range(12):
		await _step()
	_expect(_player.position.x < 16.0, "Fast player dash collides with thin wall")
	wall.queue_free()
	await _clear_enemies()

func _test_projectiles() -> void:
	await _place(&"humanoid")
	var spore := _spawn(SPORE, Vector2(100.0, 100.0))
	var shot := SporeProjectile.new()
	shot.position = Vector2(22.0, 80.0)
	shot.direction = Vector2.LEFT
	shot.shooter = weakref(spore)
	_world.add_child(shot)
	shot.set_physics_process(false)
	_player.combat.request_action(&"parry", Vector2.RIGHT * 300.0)
	for tick: int in range(4):
		await _step()
	for tick: int in range(12):
		await physics_frame
		shot._physics_process(STEP)
		if shot.reflected:
			break
	_expect(shot.reflected and _player.combat.health.current == 5, "Front parry reflects a real incoming projectile")
	for tick: int in range(60):
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			break
		await physics_frame
		shot._physics_process(STEP)
	_expect(spore.health.current == spore.health.maximum - 2, "Reflected spore deals two damage to its shooter")
	if is_instance_valid(shot):
		shot.queue_free()
	await _clear_enemies()
	await _place(&"humanoid")
	var wall := _add_solid(Vector2(30.0, 55.0), Vector2(3.0, 90.0))
	var blocked := SporeProjectile.new()
	blocked.position = Vector2(65.0, 80.0)
	blocked.direction = Vector2.LEFT
	blocked.speed = 2000.0
	_world.add_child(blocked)
	blocked.set_physics_process(false)
	await physics_frame
	blocked._physics_process(STEP)
	_expect(blocked.is_queued_for_deletion() and _player.combat.health.current == 5, "High-speed projectile stops at a thin wall")
	wall.queue_free()
	await process_frame

func _test_recovery_reset() -> void:
	await _place(&"mature")
	_player.combat.request_action(&"attack", Vector2.RIGHT * 300.0)
	await _step()
	var hit := DamageRequest.new()
	hit.amount = 99
	_player.receive_damage(hit)
	_expect(_player.combat.state == &"dead" and _player.combat.attack == null, "Death removes active hit and enters dead state")
	_player.combat.reset()
	_player.revive_animation()
	_expect(_player.combat.state == &"idle" and _player.combat.health.current == 5, "Retry restores idle state and full health")
	_expect(_player.combat.dash_cooldown_left == 0.0 and not _player.combat.air_dash_used and not _player.combat.air_attack_used, "Retry clears cooldown and aerial limits")
	_expect(_player.movement.allow_jump and _player.movement.allow_glide, "Retry restores movement permissions")

func _place(form: StringName) -> void:
	_player.cancel_actions()
	_player.combat.reset()
	_player.combat.facing = 1.0
	_player.revive_animation()
	_player.form_controller.restore_form(form)
	_player.position = Vector2(0.0, 70.0)
	_player.velocity = Vector2.ZERO
	for tick: int in range(30):
		await _step()
		if _player.is_on_floor():
			break
	_expect(_player.is_on_floor(), "%s fixture lands on floor" % form)

func _spawn(scene: PackedScene, location: Vector2) -> CombatEnemy:
	var enemy := scene.instantiate() as CombatEnemy
	enemy.position = location
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	_enemies.append(enemy)
	return enemy

func _clear_enemies() -> void:
	for enemy: CombatEnemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	await process_frame

func _add_solid(location: Vector2, size: Vector2) -> StaticBody2D:
	var solid := StaticBody2D.new()
	solid.position = location
	solid.collision_layer = 1
	solid.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	solid.add_child(collision)
	_world.add_child(solid)
	return solid

func _step(direction: float = 0.0) -> void:
	await physics_frame
	_player.combat.tick(STEP)
	_player.movement.tick(STEP, direction, false)
	_player.combat.after_movement()

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _test_parry_choreography(form: StringName) -> void:
	for scene: PackedScene in [BEETLE, PRUNER, SPORE, WARDEN]:
		for face: float in [-1.0, 1.0]:
			await _place(form)
			var combat := _player.combat
			var enemy := _spawn(scene, _player.position + Vector2(face * 50, 0))
			enemy.target = _player
			enemy.awake = true
			enemy.facing = -face
			var brain: Node = _parry_brain(enemy)
			brain.set("direction", -face)
			enemy.velocity = Vector2(0, 1)
			await physics_frame
			enemy.move_and_slide()
			enemy.attack_kind = &"charge" if enemy.beetle_behavior != null else &"lash" if enemy.spore_behavior != null else &"slash"
			enemy._set_state(&"strike")
			enemy.elapsed = 0.14
			if enemy.warden_behavior != null:
				enemy.warden_behavior.combo_planned = true
			var before: RefCounted = _parry_pose(enemy)
			_player.velocity.x = face * 220.0
			combat.set_facing(face)
			combat.request_action(&"parry", enemy.global_position)
			await _step(face)
			await _step(face)
			await _step(face)
			_expect(absf(_player.velocity.x) < 1.0, "Parry plants the running stance by the active window")
			_player.visuals.set_combat_state(combat)
			var rig := _player.visuals._spine_visual
			rig.spine_sprite.update_skeleton(0.0)
			var guard: Dictionary = {}
			for bone: StringName in [&"z2", &"z3", &"z4", &"hand_L_2", &"hand_L_1", &"hand_R", &"leg_L3", &"leg_R3"]:
				guard[bone] = rig.spine_sprite.get_skeleton().find_bone(bone).get_transform()
			var request := DamageRequest.new()
			request.source = enemy
			request.origin = enemy.global_position
			_expect(combat.receive_damage(request) == DamageRequest.Result.PARRIED, "Both facings parry each production enemy")
			rig.spine_sprite.update_skeleton(0.0)
			for bone: StringName in guard:
				var caught: Transform2D = rig.spine_sprite.get_skeleton().find_bone(bone).get_transform()
				_expect(caught.is_equal_approx(guard[bone]), "Parry success preserves the contact pose / " + bone)
			_expect(enemy.state == &"stun" and not brain.call("attack_active"), "Parry immediately closes the enemy active window")
			_expect(enemy.velocity.x * face > 0.0, "Deflection pushes the attacker away from the player")
			_expect_pose_equal(before, _parry_pose(enemy), "Enemy recoil begins at the interrupted strike")
			if enemy.warden_behavior != null:
				_expect(not enemy.warden_behavior.combo_planned, "Elite parry cancels its scheduled second strike")
			combat.cancel()
			enemy._hit_delivered = false # Even a stale contact callback must check state.
			if enemy.warden_behavior != null:
				enemy._deliver_warden_strike()
			else:
				enemy._deliver_strike()
			_expect(combat.health.current == combat.health.maximum, "Interrupted strikes cannot deliver late damage")
			enemy.elapsed = 0.12
			var opened := _parry_pose(enemy)
			var lean: float = opened.get("torso") if enemy.warden_behavior != null else opened.get("pitch")
			_expect(lean < -0.18, "Deflection visibly opens and leans back the whole body")
			var duration: float = brain.get("stun_duration")
			_expect(is_equal_approx(duration, 2.0 if enemy.warden_behavior != null else enemy.definition.parry_stun), "Elite holds two seconds; normal enemies retain their short stun")
			enemy.elapsed = duration * 0.5
			enemy._physics_process(STEP)
			_expect(enemy.state == &"stun", "Enemy holds its earned punish window")
			enemy.elapsed = duration
			var settled := _parry_pose(enemy)
			brain.call("_recover", 0.3)
			_expect_pose_equal(settled, _parry_pose(enemy), "Recovery never jumps back to the interrupted attack")
			await _clear_enemies()

func _parry_brain(enemy: CombatEnemy) -> Node:
	if enemy.beetle_behavior != null: return enemy.beetle_behavior
	if enemy.pruner_behavior != null: return enemy.pruner_behavior
	if enemy.spore_behavior != null: return enemy.spore_behavior
	return enemy.warden_behavior

func _parry_pose(enemy: CombatEnemy) -> RefCounted:
	if enemy.beetle_behavior != null: return BeetlePose.sample(enemy, 0.0)
	if enemy.pruner_behavior != null: return PrunerPose.sample(enemy, 0.0)
	if enemy.spore_behavior != null: return SporePose.sample(enemy, 0.0)
	return WardenPose.sample(enemy, 0.0)

func _expect_pose_equal(a: RefCounted, b: RefCounted, message: String) -> void:
	for property: Dictionary in a.get_property_list():
		if property.type == TYPE_FLOAT:
			_expect(is_equal_approx(a.get(property.name), b.get(property.name)), message + " / " + property.name)
		elif property.type == TYPE_VECTOR2:
			var point: Vector2 = a.get(property.name)
			_expect(point.is_equal_approx(b.get(property.name)), message + " / " + property.name)

func _test_parry_feedback(form: StringName) -> void:
	for phase: float in [0.01, 0.5, 0.99]:
		await _place(form)
		var combat := _player.combat
		var enemy := _spawn(BEETLE, _player.position + Vector2(50, 0))
		combat.request_action(&"parry", enemy.global_position)
		await _step()
		combat.elapsed = combat.tuning.parry_start + phase * combat.tuning.parry_window
		var cues: Array[float] = []
		var collect: Callable = func(kind: StringName, _point: Vector2, strength: float) -> void:
			if kind == &"parry": cues.append(strength)
		combat.feedback_requested.connect(collect)
		var request := DamageRequest.new()
		request.source = enemy
		request.origin = enemy.global_position
		_expect(combat.receive_damage(request) == DamageRequest.Result.PARRIED, "The entire active sweep can deflect")
		combat.feedback_requested.disconnect(collect)
		_expect(enemy.state == &"stun" and combat.health.current == combat.health.maximum, "Deflection interrupts the attack without taking damage")
		_expect(cues.size() == 1 and is_equal_approx(cues[0], 1.0), "Every successful sweep has the same feedback without timing grades")
		var feedback := CombatFeedback.new()
		_world.add_child(feedback)
		feedback.cue(&"parry", Vector2.ZERO, 1.0, false)
		_expect(feedback._sparks.is_empty(), "Parry emits no light particles")
		_expect(Engine.time_scale == 0.0, "Contact retains its short physical impact pause")
		feedback.clear()
		_expect(Engine.time_scale == 1.0, "Reset releases contact pause")
		feedback.queue_free()
		await _clear_enemies()
