extends "res://tests/scene/test_combat_system.gd"
## Production entity + collision fixtures. No separate playable level.
var boss: CombatEnemy
var ai: WardenBehavior

func _run() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	_add_solid(Vector2(0, 120), Vector2(1600, 40))
	_player = PLAYER.instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	await _decisions()
	await _contacts()
	await _responses()
	await _strings_and_phase()
	await _world_constraints()
	await _pose_contracts()
	_world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: %d Warden assertions: range decisions, committed facing, blade contact, parry, poise, combo openings, phase impact, wall and ledge safety" % _checks)
	else:
		for failure: String in _failures: push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _fresh(distance: float = 75.0) -> void:
	await _clear_enemies()
	await _place(&"humanoid")
	_player.position.x = distance
	boss = _spawn(WARDEN, Vector2(0, 100))
	boss.facing = 1.0
	boss.target = _player
	ai = boss.warden_behavior
	for index: int in range(3):
		await physics_frame
		boss._physics_process(STEP)
	boss.awake = true
	ai._introduced = true
	_expect(boss.is_on_floor(), "Warden fixture lands")

func _tick(count: int = 1) -> void:
	for index: int in range(count):
		await physics_frame
		boss._physics_process(STEP)

func _decisions() -> void:
	await _fresh(72)
	await _tick()
	_expect(boss.state == &"windup" and boss.attack_kind == &"slash", "Close target selects a stepping cut")
	var locked := boss.facing
	_player.position.x = -75
	await _tick(35)
	_expect(boss.facing == locked, "Crossing behind cannot rotate a committed attack")
	_expect(_player.combat.health.current == 5, "Dodging behind a slash leaves a safe opening")
	await _fresh(280)
	await _tick()
	_expect(boss.attack_kind == &"charge" and boss.state == &"windup", "Midrange target selects gap-closing rush")
	await _fresh(500)
	await _tick(12)
	_expect(boss.position.x > 4 and boss.velocity.x > 80, "Distant targets are actively pursued with acceleration")
	await _fresh(70)
	_player.position.y -= 85
	await _tick()
	_expect(boss.attack_kind == &"uppercut", "Airborne target selects a distinct rising cut")
	await _fresh(80)
	ai._last_move = &"slash"
	await _tick()
	_expect(boss.attack_kind == &"slam" and not ai.current_move().parryable, "Close pressure after slash selects the red-cross slam")
	await _fresh(75)
	_player.position.x = -75
	await _tick()
	_expect(boss.state == &"turn" and boss.facing == 1, "Turning has a planted pivot before facing changes")
	await _tick(18)
	_expect(boss.facing == -1, "Pivot completes in finite time")

func _contacts() -> void:
	for face: float in [-1.0, 1.0]:
		await _fresh(face * 80)
		boss.facing = face
		ai.direction = face
		ai._begin_attack(&"slash")
		_player.combat.health.protection_seconds = 0.0
		await _tick(27)
		_expect(_player.combat.health.current == 5 and boss.state == &"windup", "Slash cannot hit during its readable startup")
		await _tick(23)
		_expect(_player.combat.health.current == 4, "Actual blade deals one hit across the entire window on either side")
		_expect(boss.state == &"recover", "Completed cut enters a counterattack window")
		var p0 := WardenPose.loaded_pose(&"slash")
		var p1 := WardenPose.strike_pose(&"slash", 0.17, ai.tuning.slash)
		_expect(p1.hip.x - p0.hip.x > 10 and p1.torso > p0.torso, "Hips and torso drive the slash")
		_expect(p0.hand.distance_to(p1.hand) > 40 and p0.blade != p1.blade, "Weapon is carried by hand and shoulder motion")
		_player.combat.health.protection_seconds = 0.7
	await _fresh(78)
	ai._begin_attack(&"slash")
	await _tick(28)
	_player.combat.request_action(&"parry", boss.global_position)
	for frame: int in range(16):
		await physics_frame
		_player.combat.tick(STEP)
		boss._physics_process(STEP)
	_expect(_player.combat.health.current == 5 and boss.state == &"stun" and ai.reaction == &"parry", "Timed player parry deflects the production blade and stops its remaining hit checks")
	await _fresh(78)
	ai._begin_attack(&"slash")
	await _tick(28)
	_player.combat.request_action(&"dash", _player.position + Vector2(300, 0))
	for frame: int in range(15):
		await physics_frame
		_player.combat.tick(STEP)
		_player.movement.tick(STEP, 1, false)
		boss._physics_process(STEP)
	_expect(_player.combat.health.current == 5, "Player dodge can escape the committed slash")

func _responses() -> void:
	await _fresh()
	ai._begin_attack(&"slash")
	var hit := DamageRequest.new()
	hit.source = _player
	hit.origin = _player.position
	hit.knockback = Vector2(-170, -65)
	boss.receive_damage(hit)
	_expect(boss.state == &"windup" and ai.reaction_left > 0 and ai.poise == 1, "Light hit recoils armor and contributes poise without cancelling the whole action")
	ai.reaction_left = ai.reaction_duration * 0.5
	var reacted := WardenPose.sample(boss, 0)
	ai.reaction_left = 0
	var neutral := WardenPose.sample(boss, 0)
	_expect(reacted.hip != neutral.hip and reacted.head != neutral.head and reacted.shield != neutral.shield and reacted.front_foot != neutral.front_foot, "Light reaction reaches hips, head, shield and stance")
	await _fresh()
	ai._begin_attack(&"charge")
	hit.amount = 3
	hit.breaks_guard = true
	boss.receive_damage(hit)
	_expect(boss.state == &"windup" and ai.poise == 3, "One heavy hit dents the elite's poise")
	boss.receive_damage(hit)
	_expect(boss.state == &"stun" and ai.reaction == &"break" and ai.poise == 0, "Two heavy hits break poise and cancel the committed attack")
	boss.elapsed = 0.5
	boss.receive_damage(hit)
	_expect(is_equal_approx(boss.elapsed, 0.5), "Attacking a staggered elite cannot reset the stun timer")
	_expect(not ai.attack_active(), "Poise break cancels active damage immediately")
	await _fresh()
	boss.receive_parry(_player)
	_expect(is_equal_approx(ai.stun_duration, 2.0) and ai.reaction == &"parry", "Elite deflection grants exactly two seconds of stun")
	await _tick(90)
	_expect(boss.state == &"stun" and not ai.attack_active(), "Elite remains interrupted after 1.5 seconds")
	var opening_elapsed := boss.elapsed
	boss.receive_damage(hit)
	_expect(is_equal_approx(boss.elapsed, opening_elapsed), "Counterattacks do not restart the two-second stun")
	await _tick(29)
	_expect(boss.state == &"stun", "Elite holds the final frames of the two-second opening")
	await _tick(2)
	_expect(boss.state == &"recover", "Elite starts recovering once the two-second stun ends")
	ai.poise = 0
	boss.state = &"idle"
	hit.amount = 1
	hit.breaks_guard = false
	boss.receive_damage(hit)
	boss.awake = false
	await _tick(190)
	_expect(is_zero_approx(ai.poise), "Poise regenerates after pressure stops")

func _strings_and_phase() -> void:
	await _fresh(100)
	boss.second_phase = true
	ai._begin_attack(&"slash")
	_expect(ai.combo_planned, "Two-cut string is announced at the first startup")
	await _tick(51)
	_expect(boss.state == &"windup" and boss.attack_kind == &"backswing", "Second cut has its own full windup")
	await _tick(44)
	_expect(boss.state == &"recover", "Two-cut pressure always ends in recovery")
	var elapsed_before := boss.elapsed
	await _tick(25)
	_expect(boss.state == &"recover" and boss.elapsed > elapsed_before, "The elite cannot cancel its recovery to keep attacking")
	await _fresh(95)
	boss.second_phase = true
	ai._begin_attack(&"slash")
	_player.position.x = -80
	await _tick(51)
	_expect(boss.state == &"recover" and boss.attack_kind == &"slash", "Flanking denies the preannounced followup")
	await _fresh(180)
	ai._begin_attack(&"charge")
	var hit := DamageRequest.new()
	hit.amount = 21
	boss.receive_damage(hit)
	_expect(boss.second_phase and ai.phase_pending and boss.state == &"windup", "Half-health crossing does not replace an attack already telegraphed")
	await _tick(130)
	_expect(boss.state == &"overload" and not ai.phase_pending, "Phase transition waits for the full recovery")
	await _fresh(160)
	boss.second_phase = true
	var waves: Array[int] = [0]
	boss.projectile_requested.connect(func(_enemy: CombatEnemy, _point: Vector2, _direction: Vector2, wave: bool) -> void:
		if wave: waves[0] += 1
	)
	ai._begin_attack(&"slam")
	await _tick(53)
	_expect(waves[0] == 0, "Slam waves do not appear during windup or early downswing")
	await _tick(8)
	_expect(waves[0] == 2, "Second-phase slam emits exactly two waves at ground impact")
	for frame: int in range(5): ai.after_movement()
	_expect(waves[0] == 2, "Hitstop or repeated callbacks cannot duplicate ground waves")

func _world_constraints() -> void:
	await _fresh(300)
	var wall := _add_solid(Vector2(100, 20), Vector2(12, 160))
	await _tick(5)
	_expect(boss.state == &"idle", "Solid wall blocks awareness and attacks")
	wall.queue_free()
	await process_frame
	await _fresh(200)
	ai._begin_attack(&"charge")
	wall = _add_solid(Vector2(150, 20), Vector2(12, 160))
	await _tick(75)
	_expect(boss.state == &"stun" and ai.reaction == &"wall", "Baited rush hits the wall and creates a long opening")
	_expect(boss.position.x < 125, "Rush cannot tunnel through solid walls")
	wall.queue_free()
	await process_frame
	await _fresh(970)
	boss.position.x = 740
	await _tick(10)
	_expect(boss.attack_kind != &"charge", "Rush is not selected across missing floor")
	await _fresh(75)
	ai._begin_attack(&"slash")
	_player.combat.health.current = 0
	await _tick()
	_expect(boss.state == &"recover" and not ai.attack_active(), "Player death cancels pursuit and pending damage")
	await _fresh()
	var deaths: Array[int] = [0]
	boss.defeated.connect(func(_enemy: CombatEnemy) -> void: deaths[0] += 1)
	var lethal := DamageRequest.new()
	lethal.amount = 99
	boss.receive_damage(lethal)
	boss.receive_damage(lethal)
	_expect(deaths[0] == 1 and boss.state == &"dead" and not ai.attack_active(), "Death reports once and removes the attack")
	boss.position.y = 40
	boss.velocity = Vector2.ZERO
	await _tick(36)
	_expect(boss.is_on_floor(), "An airborne defeated Warden lands while its collapse animation finishes")

func _pose_contracts() -> void:
	await _fresh()
	for kind: StringName in [&"slash", &"uppercut", &"backswing"]:
		boss.attack_kind = kind
		boss._set_state(&"strike")
		boss.elapsed = ai.current_move().active_start + 0.04
		boss.visuals.set_process(false)
		boss.visuals._process(STEP)
		var pose := WardenPose.sample(boss, 0)
		var snapshot := (boss.visuals as WardenVisual).pose_snapshot()
		_expect(Vector2(snapshot["hand"]).distance_to(pose.hand) < 0.01, "Rendered %s hand matches the physics-time weapon pose" % kind)
		var tip := boss.position + Vector2(snapshot["tip"]) * Vector2(boss.facing, 1)
		var found := false
		for point: Vector2 in ai.attack_samples():
			found = found or point.distance_to(tip) < 0.01
		_expect(found, "The actual %s blade tip participates in contact sampling" % kind)
		ai._recover(0.6)
		var recovery := WardenPose.sample(boss, 0)
		_expect(recovery.hand.distance_to(pose.hand) < 0.01 and recovery.hip.distance_to(pose.hip) < 0.01, "Recovery continues from the actual %s finishing pose" % kind)
	boss._set_state(&"stun")
	ai.reaction = &"parry"
	boss.elapsed = ai.stun_duration
	var stood := WardenPose.sample(boss, 0)
	ai._recover(0.28)
	var settled := WardenPose.sample(boss, 0)
	_expect(stood.hand.distance_to(settled.hand) < 0.01, "Standing up from a stagger cannot replay a stale attack pose")
