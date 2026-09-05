extends SceneTree
## Poise must preserve enemy offense until broken, without creating stun loops.
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const ENEMIES: Array[PackedScene] = [preload("res://features/enemies/beetle.tscn"), preload("res://features/enemies/spore.tscn"), preload("res://features/enemies/pruner.tscn")]
const STEP: float = 1.0 / 60.0
var world: Node2D
var player: Player
var enemy: CombatEnemy
var checks: int = 0
var failures: PackedStringArray = []
var shots: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_meter()
	world = Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 40)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.position = Vector2(0, 120)
	floor_body.add_child(collision)
	world.add_child(floor_body)
	player = PLAYER.instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.form_controller.restore_form(&"humanoid")
	for packed: PackedScene in ENEMIES:
		await _test_offense(packed)
		await _test_stagger(packed)
	world.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("POISE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_meter() -> void:
	var first := PoiseComponent.new()
	var second := PoiseComponent.new()
	first.configure(30, 2, 15, 0.75)
	second.configure(30, 2, 15, 0.75)
	_expect(not first.take_damage(10) and first.current == 20, "Light damage consumes poise without breaking it")
	_expect(second.current == 30, "Each enemy owns independent poise")
	first.tick(1.5)
	_expect(first.current == 20, "Poise waits before recovering")
	first.tick(0.75)
	_expect(is_equal_approx(first.current, 23.75), "Recovery counts only time beyond the delay")
	_expect(not first.take_damage(0) and not first.take_damage(-10), "Nonpositive poise damage does nothing")
	_expect(first.take_damage(50) and first.broken and first.current == 0, "Overkill clamps at one poise break")
	first.tick(10)
	_expect(first.current == 0 and not first.take_damage(10), "Broken poise neither regenerates nor breaks repeatedly")
	first.finish_stagger()
	_expect(first.current == 30 and not first.broken, "Ending stagger refills poise")
	_expect(not first.take_damage(100) and first.current == 30, "Recovery protection resists an immediate second stagger")
	first.tick(0.76)
	_expect(first.take_damage(30), "Poise damage works after recovery protection ends")


func _test_offense(packed: PackedScene) -> void:
	await _spawn(packed)
	await _until(&"windup", 180)
	var started: float = enemy.elapsed
	var motion: Vector2 = enemy.velocity
	var hit := _hit(1, 10)
	enemy.receive_damage(hit)
	enemy.receive_damage(hit)
	_expect(enemy.state == &"windup" and enemy.elapsed == started, "Two light hits do not reset enemy windup")
	_expect(enemy.velocity.is_equal_approx(motion), "Unbroken poise absorbs knockback without cancelling motion")
	_expect(enemy.health.current == enemy.health.maximum - 2, "Poise never prevents health damage")
	for tick: int in range(150):
		await _step()
		if shots > 0 or player.combat.health.current < 5:
			break
	_expect(shots > 0 or player.combat.health.current < 5, "Enemy completes a real attack after taking light hits: %s" % enemy.definition.display_name)


func _test_stagger(packed: PackedScene) -> void:
	await _spawn(packed)
	enemy.awake = false
	enemy._set_state(&"recover")
	for pair: Vector2 in [Vector2(1, 10), Vector2(1, 10), Vector2(2, 20)]:
		enemy.receive_damage(_hit(int(pair.x), pair.y))
	_expect(enemy.health.current == enemy.health.maximum - 4 and enemy.health.current > 0, "Small enemy survives one three-hit combo")
	if enemy.definition.kind == EnemyDefinition.Kind.PRUNER:
		_expect(enemy.state != &"stun" and enemy.poise.current == 5, "Armored pruner has more poise than other small enemies")
		enemy.receive_damage(_hit(1, 5))
	_expect(enemy.state == &"stun" and enemy.poise.broken, "Depleted poise interrupts the enemy")
	for tick: int in range(12):
		await _step()
	var elapsed: float = enemy.elapsed
	var motion: Vector2 = enemy.velocity
	var health: int = enemy.health.current
	enemy.receive_damage(_hit(1, 100))
	enemy.receive_parry(player)
	_expect(enemy.elapsed == elapsed and enemy.velocity.is_equal_approx(motion), "Extra hits and parry do not restart stagger or launch the enemy again")
	_expect(enemy.health.current == health - 1, "Staggered enemies still take health damage")
	for tick: int in range(120):
		if enemy.state != &"stun":
			break
		await _step()
	_expect(enemy.state != &"stun" and enemy.poise.current == enemy.poise.maximum, "Stagger ends and poise refills")
	health = enemy.health.current
	enemy.receive_damage(_hit(1, 100))
	_expect(enemy.state != &"stun" and enemy.health.current == health - 1, "Recovery protection blocks stagger but still permits damage")
	await _spawn(packed)
	enemy.receive_parry(player)
	_expect(enemy.state == &"stun" and enemy.poise.broken, "Successful parry forces an opening from full poise")


func _spawn(packed: PackedScene) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
		await process_frame
	shots = 0
	player.combat.reset()
	enemy = packed.instantiate() as CombatEnemy
	enemy.position = Vector2(0, 100)
	enemy.facing = 1.0
	world.add_child(enemy)
	enemy.set_physics_process(false)
	player.position = Vector2(180 if enemy.spore_behavior != null else 44, 100)
	enemy.projectile_requested.connect(_on_shot)
	enemy.velocity = Vector2(0, 1)
	await _step()
	enemy.target = player
	enemy.awake = true


func _hit(amount: int, poise_damage: float) -> DamageRequest:
	var hit := DamageRequest.new()
	hit.amount = amount
	hit.poise_damage = poise_damage
	# Rear hit isolates poise from the pruner's separate frontal shield.
	hit.origin = enemy.global_position - Vector2(enemy.facing * 60, 20)
	hit.knockback = Vector2(enemy.facing * 100, -65)
	return hit


func _on_shot(_enemy: CombatEnemy, _point: Vector2, _direction: Vector2, _wave: bool) -> void:
	shots += 1


func _until(state: StringName, limit: int) -> void:
	for tick: int in range(limit):
		if enemy.state == state:
			return
		await _step()
	_expect(false, "Timed out waiting for %s" % state)


func _step() -> void:
	await physics_frame
	enemy._physics_process(STEP)
	player.combat.health.tick(STEP)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
