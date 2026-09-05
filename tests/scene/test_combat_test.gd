extends SceneTree
## Smoke the practice lane's assembly and its existing combat/lifecycle wiring.
const SCENE: PackedScene = preload("res://scenes/levels/combat_test.tscn")
var _failures: PackedStringArray = []
var _checks: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := SCENE.instantiate()
	root.add_child(level)
	current_scene = level
	await _frames(20)
	var player: Player = level.player
	_expect(player.current_form_id() == &"humanoid", "Player starts ready for combat")
	_expect(player.is_on_floor(), "Player stands on the platform")
	_expect(player.combat.health.current == 5, "Player starts with full health")
	_expect(level.platform.piece_size.x == 5000.0, "The platform is 5000 pixels long")
	_expect(level.enemies.get_child_count() == 4, "Four existing enemy types are placed")
	for enemy: CombatEnemy in level.enemies.get_children():
		_expect(enemy.target == player and not enemy.awake, "Enemies wait for the player to approach")
		_expect(enemy.is_on_floor(), "Each enemy stands on the platform")
	for x: float in [20.0, 1200.0, 2500.0, 3800.0, 4980.0]:
		var ray := PhysicsRayQueryParameters2D.create(Vector2(x, 530), Vector2(x, 590), 1)
		_expect(not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "The lane has continuous ground")

	var spore: CombatEnemy = level.enemies.get_node("Spore")
	player.global_position = Vector2(1620, 560)
	player.velocity = Vector2.ZERO
	var shots: Array[int] = [0]
	spore.projectile_requested.connect(func(_enemy: CombatEnemy, _point: Vector2, _direction: Vector2, _wave: bool) -> void: shots[0] += 1)
	for frame: int in range(360):
		await _frames(1)
		if shots[0] > 0:
			break
	_expect(spore.awake, "Approaching activates the spore")
	_expect(shots[0] > 0 and level.projectiles.get_child_count() > 0, "A real enemy attack creates a live projectile")
	_expect(not (level.enemies.get_node("Warden") as CombatEnemy).awake, "Distant enemies remain inactive")

	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	level._unhandled_input(pause_event)
	_expect(paused and level.hud.is_overlay_visible(), "Esc opens the pause menu")
	await process_frame
	level.hud.resume_requested.emit()
	_expect(not paused and not level.hud.is_overlay_visible(), "Resume restores gameplay")

	var lethal := DamageRequest.new()
	lethal.amount = player.combat.health.maximum
	player.combat.health.protection_left = 0.0
	player.combat.health.take_damage(lethal)
	_expect(paused and level.hud.is_overlay_visible(), "Death offers a restart")
	await process_frame
	var restart_event := InputEventAction.new()
	restart_event.action = &"restart"
	restart_event.pressed = true
	level._unhandled_input(restart_event)
	await _frames(20)
	level = current_scene
	_expect(not paused and is_equal_approx(Engine.time_scale, 1.0), "R clears pause and hit stop")
	_expect(level.player.combat.health.current == 5 and level.player.global_position.x < 200.0, "R restores player health and spawn")
	_expect(level.enemies.get_child_count() == 4 and level.projectiles.get_child_count() == 0, "R restores all monsters and removes projectiles")

	level.queue_free()
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	print("%s: %d combat test scene checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	quit(0 if _failures.is_empty() else 1)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
