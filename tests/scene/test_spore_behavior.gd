extends SceneTree
## Real entity/Player contracts in a minimal physics fixture, not a playable level.
const SPORE: PackedScene = preload("res://features/enemies/spore.tscn")
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const STEP: float = 1.0 / 60.0
var world: Node2D
var player: Player
var enemy: CombatEnemy
var shots: Array[Dictionary] = []
var failures: PackedStringArray = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_solid(Vector2(0, 110), Vector2(1200, 20))
	player = PLAYER.instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.form_controller.restore_form(&"humanoid")
	await _spawn(190)
	await _until(&"notice", 30)
	await _until(&"windup", 60)
	_expect(enemy.attack_kind == &"spit", "Distant target selects pressure spit")
	_expect(enemy.spore_behavior.spit_cooldown_left > 2.0, "Spit spends an independent cooldown")
	while not enemy.spore_behavior.aim_locked:
		_expect(shots.is_empty(), "No shot before the visible release")
		await _step()
	var locked_aim: float = enemy.spore_behavior.aim_angle
	player.position = Vector2(-160, 50)
	await _until(&"recover", 100)
	_expect(shots.size() == 1, "Exactly one projectile is emitted per spit")
	_expect(enemy.facing == 1.0 and is_equal_approx(enemy.spore_behavior.aim_angle, locked_aim), "Late dodge cannot be tracked after aim lock")
	_expect((shots[0].direction as Vector2).x > 0.0, "Projectile keeps the committed direction")
	_expect((shots[0].point as Vector2).distance_to(shots[0].muzzle) < 0.01, "Physics release matches the visible animated mouth")
	_expect(absf(enemy.position.x) < 0.01, "Spit loads rooted body without moving the collider")
	await _until(&"turn", 100)
	await _until(&"idle", 60)
	_expect(enemy.facing == -1.0, "Turning is delayed until the recovery finishes")
	await _spawn(49)
	await _until(&"windup", 70)
	_expect(enemy.attack_kind == &"lash", "Close target selects a body lash")
	while enemy.state == &"windup":
		_expect(player.combat.health.current == 5, "Lash windup cannot hit")
		await _step()
	await _until(&"recover", 60)
	_expect(player.combat.health.current == 4, "Body lash hits exactly once")
	_expect(shots.is_empty(), "Body lash does not emit hidden projectiles")
	player.combat.health.protection_left = 0.0
	enemy._deliver_strike()
	_expect(player.combat.health.current == 4, "No stale hitbox in recovery")
	await _until(&"idle", 100)
	enemy.spore_behavior.lash_cooldown_left = 0.5
	await _step()
	_expect(enemy.state == &"idle", "Close-range cooldown leaves an opening")
	# Grounded rooted behavior cannot attack while falling or across occluding terrain.
	await _spawn(190)
	var wall: StaticBody2D = _solid(Vector2(70, 55), Vector2(5, 90))
	for tick: int in range(100):
		await _step()
	_expect(enemy.state == &"idle" and shots.is_empty(), "No awareness or firing through a wall")
	wall.queue_free()
	await process_frame
	await _until(&"windup", 70)
	enemy.target = null
	await _step()
	_expect(enemy.state == &"recover" and shots.is_empty(), "Lost target cancels unreleased shot")
	await _spawn(180)
	await _until(&"windup", 70)
	enemy.spore_behavior.alerted = false
	player.position.x = 700
	await _until(&"idle", 150)
	for tick: int in range(70):
		await _step()
	_expect(not enemy.spore_behavior.alerted, "Losing range clears alert after the memory window")
	# Cancel immediately, including during the pre-release part of the strike.
	for face: float in [-1.0, 1.0]:
		await _spawn(180 * face, face)
		await _until(&"strike", 100)
		var hit := DamageRequest.new()
		hit.origin = enemy.position + Vector2(face * 50, -20)
		hit.knockback = Vector2(-face * 120, -60)
		hit.poise_damage = enemy.poise.maximum
		enemy.receive_damage(hit)
		_expect(enemy.state == &"stun" and enemy.spore_behavior.reaction == &"light", "Poise-breaking hit interrupts pressure release")
		_expect(enemy.spore_behavior.hit_direction == -face, "Reaction follows world-space hit direction")
		enemy.awake = false
		enemy.target = null
		await _until(&"idle", 100)
		_expect(shots.is_empty() and enemy.is_on_floor(), "Cancelled shot stays cancelled; reaction lands without target")
	await _spawn(49)
	var heavy := DamageRequest.new()
	heavy.amount = 2
	heavy.poise_damage = 35.0
	heavy.knockback = Vector2(-150, -95)
	enemy.receive_damage(heavy)
	_expect(enemy.spore_behavior.reaction == &"heavy" and enemy.spore_behavior.stun_duration >= 0.7, "Heavy damage opens a longer punish window")
	await _spawn(49)
	enemy.receive_parry(player)
	_expect(enemy.spore_behavior.reaction == &"parry" and enemy.velocity.y < 0, "Parry unroots and lifts the pressure sac")
	_verify_poses()
	enemy._set_state(&"idle")
	enemy.position.y = 35.0 # Airborne death fixture; gameplay uses velocity.
	var deaths: Array[int] = [0]
	enemy.defeated.connect(func(_value: CombatEnemy) -> void: deaths[0] += 1)
	heavy.amount = 99
	enemy.receive_damage(heavy)
	enemy.receive_damage(heavy)
	_expect(deaths[0] == 1 and enemy.state == &"dead", "Death emitted once")
	_expect(not enemy.spore_behavior.attack_active(), "Death instantly disables offense")
	_expect(enemy.definition.maximum_health == 8, "Shared data is immutable")
	for tick: int in range(45):
		await _step()
	_expect(enemy.is_on_floor() and absf(enemy.position.y - 100.0) < 0.1, "Airborne corpse falls onto world ground instead of freezing or passing through it")
	world.queue_free()
	await process_frame
	print("SPORE: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _verify_poses() -> void:
	var visual: SporeVisual = enemy.visuals as SporeVisual
	visual.set_process(false)
	for face: float in [-1.0, 1.0]:
		enemy.facing = face
		enemy.spore_behavior.aim_point = enemy.global_position + Vector2(face * 180, -26)
		for action: StringName in [&"spit", &"lash"]:
			enemy.attack_kind = action
			for state: StringName in [&"idle", &"notice", &"turn", &"windup", &"strike", &"recover", &"stun", &"dead"]:
				enemy._set_state(state)
				for tick: int in range(50):
					enemy.elapsed = tick * STEP
					visual._process(STEP)
					var pose: Dictionary = visual.pose_snapshot()
					for key: String in ["body", "nozzle", "leaf", "roots"]:
						_expect((pose[key] as Transform2D).is_finite(), "Finite connected body transforms")
					_expect(enemy.get_node("BodyShape").scale == Vector2.ONE, "Animation never scales collision")
		enemy._set_state(&"idle")
		enemy.attack_kind = &"spit"
		visual._process(1.0)
		var rest: Dictionary = visual.pose_snapshot()
		enemy._set_state(&"windup")
		enemy.elapsed = enemy.spore_behavior.tuning.spit_windup
		visual._process(1.0)
		var loaded: Dictionary = visual.pose_snapshot()
		for key: String in ["body", "nozzle", "leaf", "roots"]:
			_expect(not (loaded[key] as Transform2D).is_equal_approx(rest[key]), "Windup recruits every body part: " + key)
		for i: int in range(10):
			visual._process(0.0)
		_expect((visual.pose_snapshot().body as Transform2D).is_equal_approx(loaded.body), "Repeated sampling does not accumulate transforms")
		enemy._set_state(&"strike")
		enemy.elapsed = enemy.spore_behavior.tuning.spit_release
		visual._process(0.1)
		var physical_mouth: Vector2 = SporePose.sample(enemy, 0.0).muzzle_local() * Vector2(face, 1)
		_expect((visual.pose_snapshot().muzzle as Vector2).distance_to(physical_mouth) < 0.01, "Both facing directions align visual and physics muzzle")

func _shot(_actor: CombatEnemy, point: Vector2, direction: Vector2, _wave: bool) -> void:
	var visual: SporeVisual = enemy.visuals as SporeVisual
	visual._process(0.1)
	shots.append({"point": point, "direction": direction, "muzzle": enemy.global_position + (visual.pose_snapshot().muzzle as Vector2)})

func _spawn(target_x: float, face: float = 1.0) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
		await process_frame
	shots.clear()
	player.combat.reset()
	player.position = Vector2(target_x, 100)
	enemy = SPORE.instantiate() as CombatEnemy
	enemy.position = Vector2(0, 100)
	enemy.facing = face
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.projectile_requested.connect(_shot)
	enemy.velocity = Vector2(0, 1)
	await _step()
	enemy.target = player
	enemy.awake = true

func _until(state: StringName, limit: int) -> void:
	for tick: int in range(limit):
		if enemy.state == state:
			return
		await _step()
	_expect(false, "Timed out waiting for %s (was %s)" % [state, enemy.state])

func _step() -> void:
	await physics_frame
	enemy._physics_process(STEP)
	player.combat.health.tick(STEP)

func _solid(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
