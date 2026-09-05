extends SceneTree
## Behavior checks for the production elastic component and its visual-only solver.
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const VINE: PackedScene = preload("res://features/combat/visuals/vine_whip_visual.tscn")
const MOTION = preload("res://features/combat/visuals/vine_whip_motion.gd")
const STEP: float = 1.0 / 60.0
var _actor: Player
var _host: Node2D
var _vine: VineWhipVisual
var _checks: int = 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_host = Node2D.new()
	root.add_child(_host)
	_host.transform = Transform2D(0.21, Vector2(170.0, -40.0)).scaled_local(Vector2.ONE * 1.25)
	_actor = PLAYER.instantiate() as Player
	_host.add_child(_actor)
	_actor.process_mode = Node.PROCESS_MODE_DISABLED
	_vine = VINE.instantiate() as VineWhipVisual
	_host.add_child(_vine)
	for form: StringName in [&"humanoid", &"mature"]:
		_actor.form_controller.restore_form(form)
		var profile: VineWhipProfile = _vine.mature_profile if form == &"mature" else _vine.humanoid_profile
		_test_solver_pull(profile)
		for facing: float in [1.0, -1.0]:
			for action: StringName in [&"light_1", &"light_2", &"light_3", &"heavy", &"air"]:
				_test_moving_hand(form, action, facing, profile)
			_test_landing(form, facing)
	_host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: %d vine hand-coupling assertions: elastic lag, actual bone root/tangent, bounded spans and bends, duplicate-clock isolation, landing and interruption cleanup" % _checks)
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _hand(facing: float, time: float) -> Transform2D:
	var hand := Transform2D(0.25 + sin(time * 16.0) * 0.5, Vector2((9.0 + sin(time * 9.0) * 7.0) * facing, -25.0 + sin(time * 13.0) * 5.0))
	hand.x.x *= facing
	hand.y.x *= facing
	return hand

func _test_moving_hand(form: StringName, action: StringName, facing: float, profile: VineWhipProfile) -> void:
	var combat: CombatController = _actor.combat
	combat.cancel()
	_vine.clear_attack()
	combat.state = &"attack"
	combat.attack = combat.tuning.find_attack(action)
	combat.facing = facing
	var duration: float = combat.attack.duration() * combat.time_scale_for_form()
	var key: String = "%s/%s/%s" % [form, action, facing]
	for tick: int in range(int(ceil(duration / STEP))):
		combat.elapsed = tick * STEP
		var hand: Transform2D = _hand(facing, combat.elapsed)
		_vine.sample_combat(combat, form, hand)
		var points: PackedVector2Array = _vine.chain_world_points()
		_expect(points.size() == 10, key + " exposes ten visible bone points")
		if points.size() != 10:
			continue
		var world_hand: Transform2D = _host.global_transform * hand
		_expect(points[0].distance_to(world_hand.origin) < 0.003, key + " world-space root stays on moving hand")
		_expect((points[1] - points[0]).normalized().dot(world_hand.x.normalized()) > 0.9999, key + " first span follows wrist tangent")
		var span: float = _vine.chain_length_limit() / 9.0
		var length: float = 0.0
		var valid_lengths: bool = span > 0.0
		var valid_bends: bool = true
		for index: int in range(1, points.size()):
			var offset: Vector2 = points[index] - points[index - 1]
			length += offset.length()
			valid_lengths = valid_lengths and points[index].is_finite() and absf(offset.length() - span) < 0.003
			if index >= 2:
				valid_bends = valid_bends and absf((points[index - 1] - points[index - 2]).angle_to(offset)) <= profile.max_joint_bend + 0.001
		_expect(valid_lengths and length <= _vine.chain_length_limit() + 0.01, key + " each physical span and total length stay bounded")
		_expect(valid_bends, key + " hand pull does not kink any joint beyond its limit")
		_vine.sample_combat(combat, form, hand)
		_expect(_same_points(points, _vine.chain_world_points()), key + " repeated clock and hand do not integrate twice")
		var refined := hand
		refined.origin += Vector2(4.0, -3.0)
		_vine.sample_combat(combat, form, refined)
		_expect(_vine.chain_world_points()[0].distance_to((_host.global_transform * refined).origin) < 0.003, key + " same-clock refined hand still pins its root")
		_vine.sample_combat(combat, form, hand)
		_expect(_same_points(points, _vine.chain_world_points()), key + " temporary same-clock hand refinement cannot mutate cached simulation")
	combat.cancel()
	_vine.sample_combat(combat, form, _hand(facing, 0.0))
	_expect(_vine.chain_world_points().is_empty() and _vine._trail_shapes.is_empty(), key + " interruption clears displayed chain and trails")

func _test_solver_pull(profile: VineWhipProfile) -> void:
	# Fixed goals isolate inertia from the changing authored attack animation.
	var solver = MOTION.new()
	var original := PackedVector2Array()
	for index: int in range(10):
		original.append(Vector2(index * 8.0, 0.0))
	solver.sample(original, Vector2.RIGHT, 8.0, 0.0, profile)
	var translated := PackedVector2Array()
	for point: Vector2 in original:
		translated.append(point + Vector2(0.0, 12.0))
	var pulled: PackedVector2Array = solver.sample(translated, Vector2.RIGHT, 8.0, STEP, profile)
	var initial_tip_error: float = pulled[9].distance_to(translated[9])
	_expect(pulled[0].distance_to(translated[0]) < 0.001 and pulled[1].distance_to(translated[1]) < 0.001, String(profile.form_id) + " rapid translation immediately pulls the hand and first span")
	_expect(pulled[9].y > 0.0 and pulled[9].y < 11.5 and initial_tip_error > 0.5, String(profile.form_id) + " distal chain follows with measurable delay")
	for tick: int in range(2, 31):
		pulled = solver.sample(translated, Vector2.RIGHT, 8.0, tick * STEP, profile)
	_expect(pulled[9].distance_to(translated[9]) < initial_tip_error, String(profile.form_id) + " distal chain catches up while the hand holds")
	var direction: Vector2 = Vector2.RIGHT.rotated(0.5)
	var turned := PackedVector2Array()
	for index: int in range(10):
		turned.append(translated[0] + direction * index * 8.0)
	var rotated: PackedVector2Array = solver.sample(turned, direction, 8.0, 31 * STEP, profile)
	_expect((rotated[1] - rotated[0]).normalized().dot(direction) > 0.9999, String(profile.form_id) + " rapid wrist turn immediately changes root direction")
	_expect(rotated[9].distance_to(turned[9]) > 0.5, String(profile.form_id) + " distal chain lags a rapid wrist turn")
	var held: PackedVector2Array = solver.sample(turned, direction, 8.0, 31 * STEP, profile)
	_expect(_same_points(rotated, held), String(profile.form_id) + " solver does not advance at an unchanged clock")
	solver.clear()
	var restarted: PackedVector2Array = solver.sample(original, Vector2.RIGHT, 8.0, 0.0, profile)
	_expect(_same_points(restarted, original), String(profile.form_id) + " cleared solver cannot carry previous attack inertia")

func _test_landing(form: StringName, facing: float) -> void:
	var combat: CombatController = _actor.combat
	combat.cancel()
	_vine.clear_attack()
	combat.state = &"attack"
	combat.attack = combat.tuning.find_attack(&"air")
	combat.facing = facing
	var hand: Transform2D = _hand(facing, 0.14)
	for tick: int in range(10):
		combat.elapsed = tick * STEP
		_vine.sample_combat(combat, form, hand)
	combat.landing_from_elapsed = combat.elapsed
	combat.landing_from_progress = combat.progress()
	combat.state = &"attack_landing"
	combat.elapsed = 0.0
	_vine.sample_combat(combat, form, hand)
	var initial_length: float = _vine.chain_length_limit()
	_expect(_vine.visible and _vine._trail_shapes.is_empty(), String(form) + " contact keeps the attached vine but removes attack trails")
	for tick: int in range(1, 5):
		combat.elapsed = tick * STEP
		_vine.sample_combat(combat, form, hand)
	_expect(_vine.chain_length_limit() < initial_length * 0.25, String(form) + " landing retracts the physical vine before disappearing")
	combat.elapsed = 0.08
	_vine.sample_combat(combat, form, hand)
	_expect(not _vine.visible and _vine.chain_world_points().is_empty() and _vine._trail_shapes.is_empty(), String(form) + " end of landing leaves no visible vine or trail")

func _same_points(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for index: int in range(a.size()):
		if a[index].distance_to(b[index]) > 0.001:
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
