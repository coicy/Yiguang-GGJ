extends SceneTree
## Production beetle and player, minimal physics fixture (no playable test level).
const BEETLE: PackedScene = preload("res://features/enemies/beetle.tscn")
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const STEP: float = 1.0 / 60.0
var world: Node2D
var player: Player
var enemy: CombatEnemy
var failures: PackedStringArray = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_solid(Vector2(0, 110), Vector2(1000, 20))
	player = PLAYER.instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.form_controller.restore_form(&"humanoid")
	await _spawn(0, 44)
	await _until(&"windup", 90)
	_expect(enemy.attack_kind == &"horn", "Near target chooses horn lift")
	var start_x := enemy.position.x
	while enemy.state == &"windup":
		_expect(player.combat.health.current == 5, "Windup never damages")
		await _step()
	_expect(absf(enemy.position.x - start_x) < 0.5, "Feet plant for anticipation")
	await _until(&"recover", 60)
	_expect(player.combat.health.current == 4, "Horn hits exactly once in active frames")
	player.combat.health.protection_left = 0.0
	enemy._deliver_strike()
	_expect(player.combat.health.current == 4, "Recovery has no stale damage")
	await _spawn(0, 170)
	await _until(&"windup", 90)
	_expect(enemy.attack_kind == &"charge", "Midrange selects charge")
	_expect(enemy.beetle_behavior.charge_cooldown_left > 2.0, "Charge spends its own cooldown")
	player.position.x = -60.0
	await _until(&"recover", 120)
	_expect(enemy.facing == 1.0 and enemy.position.x > 65.0, "Charge locks facing and commits when dodged")
	_expect(player.combat.health.current == 5, "Dodging behind charge avoids damage")
	await _until(&"turn", 90)
	await _until(&"idle", 60)
	_expect(enemy.facing == -1.0, "Beetle plants and turns after recovery")
	enemy.beetle_behavior.charge_cooldown_left = 1.0
	player.position = enemy.position + Vector2(-150, 0)
	await _step()
	_expect(enemy.state != &"windup", "Charge cooldown prevents immediate reuse at midrange")
	await _spawn(0, 44)
	player.position.y -= 75.0
	for tick: int in range(80):
		await _step()
	_expect(enemy.state not in [&"windup", &"strike"], "Beetle cannot horn-lift a target far above its reach")
	await _spawn(0, 44)
	await _until(&"windup", 90)
	enemy.target = null
	await _step()
	_expect(enemy.state == &"recover", "Losing target cancels windup without a stale hit")
	# Charge makes physical contact with an obstacle introduced after commitment.
	await _spawn(0, 170)
	await _until(&"windup", 90)
	var wall := _solid(Vector2(72, 65), Vector2(4, 70))
	await _until(&"stun", 120)
	_expect(enemy.beetle_behavior.reaction == &"wall" and enemy.position.x < 54.1, "Thin wall stops charge and causes a distinct stumble")
	_expect(player.combat.health.current == 5, "Wall impact cannot deal damage through geometry")
	wall.queue_free()
	await process_frame
	await _spawn(450, 580)
	for tick: int in range(150):
		await _step()
	_expect(enemy.position.x <= 477.0 and enemy.is_on_floor(), "AI stops before a platform edge")
	_expect(enemy.attack_kind != &"charge", "AI refuses charge lane with a gap")
	# Receiving hits must work even without a live target/encounter.
	for face: float in [-1.0, 1.0]:
		await _spawn(0, 44)
		enemy.facing = face
		var hit := DamageRequest.new()
		hit.origin = enemy.position + Vector2(face * 50, -15)
		hit.knockback = Vector2(-face * 100, -60)
		hit.poise_damage = enemy.poise.maximum
		enemy.receive_damage(hit)
		_expect(enemy.state == &"stun" and enemy.beetle_behavior.reaction == &"light", "Poise-breaking hit interrupts the current attack")
		_expect(enemy.beetle_behavior.hit_direction == -face, "Hit direction is mirrored correctly")
		enemy.awake = false
		enemy.target = null
		await _until(&"idle", 120)
		_expect(enemy.is_on_floor(), "Hit reaction lands and resolves after losing target")
	await _spawn(0, 44)
	var heavy := DamageRequest.new()
	heavy.amount = 2
	heavy.poise_damage = 35.0
	heavy.knockback = Vector2(-150, -100)
	enemy.receive_damage(heavy)
	_expect(enemy.beetle_behavior.reaction == &"heavy", "Heavy hit uses its own full body recoil")
	await _spawn(0, 44)
	enemy.receive_parry(player)
	_expect(enemy.beetle_behavior.reaction == &"parry" and enemy.beetle_behavior.stun_duration >= 0.7, "Parry opens a punish window")
	await _verify_poses()
	heavy.amount = 99
	var deaths: Array[int] = [0]
	enemy.defeated.connect(func(_value: CombatEnemy) -> void: deaths[0] += 1)
	enemy.receive_damage(heavy)
	enemy.receive_damage(heavy)
	_expect(enemy.state == &"dead" and deaths[0] == 1, "Death reported once")
	_expect(not enemy.beetle_behavior.attack_active(), "Death removes attack immediately")
	_expect(enemy.definition.maximum_health == 8, "Shared enemy data stays unchanged")
	world.queue_free()
	await process_frame
	print("BEETLE: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _verify_poses() -> void:
	var visual := enemy.visuals as BeetleVisual
	visual.set_process(false)
	for face: float in [-1.0, 1.0]:
		enemy.facing = face
		for action: StringName in [&"horn", &"charge"]:
			enemy.attack_kind = action
			for state: StringName in [&"idle", &"notice", &"turn", &"windup", &"strike", &"recover", &"stun", &"dead"]:
				enemy._set_state(state)
				for time: float in [0.0, 0.04, 0.09, 0.2, 0.4, 0.6]:
					enemy.elapsed = time
					visual._process(STEP)
					var pose := visual.pose_snapshot()
					_expect((pose.body as Transform2D).is_finite() and (pose.head as Transform2D).is_finite(), "Pose transforms remain finite")
					for foot: Vector2 in pose.feet:
						_expect(foot.is_finite(), "Six feet remain finite")
					_expect(enemy.get_node("BodyShape").scale == Vector2.ONE, "Pose does not scale physics")
	enemy._set_state(&"idle")
	enemy.elapsed = 0.0
	visual._process(1.0)
	var resting := visual.pose_snapshot()
	enemy._set_state(&"windup")
	enemy.elapsed = 0.5
	visual._process(0.2)
	var loaded := visual.pose_snapshot()
	_expect((resting.body as Transform2D).origin.distance_to((loaded.body as Transform2D).origin) > 3.0, "Anticipation changes the body center of mass")
	_expect(absf((resting.head as Transform2D).get_rotation() - (loaded.head as Transform2D).get_rotation()) > 0.1, "Anticipation involves the head")
	_expect((resting.feet[0] as Vector2).distance_to(loaded.feet[0]) > 1.0, "Anticipation involves the legs")
	_expect(absf((loaded.shell as Transform2D).get_rotation()) > 0.05, "Wing case follows the loaded thorax")
	# Zero-time repeated evaluations cannot accumulate transforms.
	for repeat: int in range(20):
		visual._process(0.0)
	_expect((visual.pose_snapshot().body as Transform2D).is_equal_approx(loaded.body), "Repeated pose evaluation never accumulates offsets")
	enemy._set_state(&"idle")
	enemy.facing = 1.0
	enemy.velocity.x = 28.0
	visual._stride = 0.0
	visual._last_position = enemy.global_position
	visual._process(0.2)
	var planted_foot: Vector2 = enemy.position + visual.pose_snapshot().feet[0]
	enemy.position.x += 1.0 # Controlled fixture displacement, not runtime movement.
	visual._process(STEP)
	var moved_foot: Vector2 = enemy.position + visual.pose_snapshot().feet[0]
	_expect(planted_foot.distance_to(moved_foot) < 0.01, "Support foot stays planted as body advances")

func _spawn(x: float, target_x: float) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
		await process_frame
	player.combat.reset()
	player.position = Vector2(target_x, 100)
	enemy = BEETLE.instantiate() as CombatEnemy
	enemy.position = Vector2(x, 100)
	enemy.facing = 1.0
	world.add_child(enemy)
	enemy.set_physics_process(false)
	# Land before allowing intent evaluation.
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
