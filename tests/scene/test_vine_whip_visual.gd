extends SceneTree
## Contracts for the shipped vine component and Player composition; no playable fixture level.
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const VINE: PackedScene = preload("res://features/combat/visuals/vine_whip_visual.tscn")
const ACTIONS: Array[StringName] = [&"light_1", &"light_2", &"light_3", &"heavy", &"air"]
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
	_actor = PLAYER.instantiate() as Player
	_host.add_child(_actor)
	_actor.process_mode = Node.PROCESS_MODE_DISABLED
	_vine = VINE.instantiate() as VineWhipVisual
	_host.add_child(_vine)
	for form: StringName in [&"humanoid", &"mature"]:
		_actor.form_controller.restore_form(form)
		for action: StringName in ACTIONS:
			for facing: float in [1.0, -1.0]:
				_test_timeline(form, action, facing)
		_test_fixed_leaf_size(form)
		_test_cleanup(form)
		_test_player_attachment(form)
		_test_parry_sweep(form)
	await _test_frozen_clock()
	_host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: %d vine visual assertions: ten actions, both facings, attachment, phase synchronization, fixed leaf scale, cancellation and frozen clock" % _checks)
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _test_timeline(form: StringName, action: StringName, facing: float) -> void:
	var combat: CombatController = _actor.combat
	combat.cancel()
	combat.state = &"attack"
	combat.attack = combat.tuning.find_attack(action)
	combat.facing = facing
	var definition: AttackDefinition = combat.attack
	var timing: float = combat.time_scale_for_form()
	var hand := Transform2D(0.42, Vector2(9.0 * facing, -25.0))
	hand.x.x *= facing
	hand.y.x *= facing
	var samples: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(definition.windup * 0.5, 0.5), Vector2(definition.windup, 1.0), Vector2(definition.windup + definition.active * 0.5, 1.5), Vector2(definition.windup + definition.active, 2.0), Vector2(definition.windup + definition.active + definition.recovery * 0.5, 2.5)]
	var key: String = "%s/%s/%s" % [form, action, facing]
	for sample: Vector2 in samples:
		combat.elapsed = sample.x * timing
		_vine.sample_combat(combat, form, hand)
		_expect(is_equal_approx(_vine.sampled_phase, sample.y), key + " samples configured attack phases")
		_expect(_vine.sampled_animation == StringName(String(form) + "/" + String(action)), key + " selects its editable animation")
		_expect(_vine.position.distance_to(hand.origin) < 0.01, key + " root follows the hand in parent coordinates")
		_expect(_vine.tip_position.is_finite() and _vine.transform.is_finite(), key + " keeps finite geometry")
		_expect(_bones_are_finite(_vine), key + " keeps each bone finite")
		if sample.y >= 1.0 and sample.y < 2.0:
			_expect(_vine.visible, key + " is visible throughout its hit window")
			var reach: float = definition.reach * combat.reach_scale()
			_expect(_vine.tip_position.x * facing <= reach + 12.0, key + " keeps the visible curl inside the authored hit boundary tolerance")
		var held_tip: Vector2 = _vine.tip_position
		var held_phase: float = _vine.sampled_phase
		_vine.sample_combat(combat, form, hand)
		_expect(_vine.tip_position.distance_to(held_tip) < 0.001 and is_equal_approx(_vine.sampled_phase, held_phase), key + " repeated samples cannot accumulate movement")
	combat.elapsed = (definition.windup + definition.active + definition.recovery * 0.85) * timing
	_vine.sample_combat(combat, form, hand)
	_expect(absf(_vine.tip_position.x - hand.origin.x) < definition.reach * combat.reach_scale() * 0.7, key + " retracts away from full hit distance during recovery")
	_vine.clear_attack()
	_expect(not _vine.visible, key + " explicit clear hides the entire vine")

func _test_fixed_leaf_size(form: StringName) -> void:
	var combat: CombatController = _actor.combat
	combat.state = &"attack"
	combat.attack = combat.tuning.find_attack(&"light_1").duplicate(true) as AttackDefinition
	combat.facing = 1.0
	combat.elapsed = (combat.attack.windup + combat.attack.active * 0.5) * combat.time_scale_for_form()
	_vine.sample_combat(combat, form, Transform2D(0.0, Vector2(8.0, -24.0)))
	var before: Dictionary = _leaf_scales(_vine)
	_expect(before.size() >= 2, String(form) + " has separately attached leaf silhouettes")
	combat.attack.reach *= 1.7
	_vine.sample_combat(combat, form, Transform2D(0.0, Vector2(8.0, -24.0)))
	var after: Dictionary = _leaf_scales(_vine)
	for leaf: String in before:
		_expect(after.has(leaf) and (before[leaf] as Vector2).distance_to(after[leaf]) < 0.001, String(form) + " changing reach does not stretch " + leaf)

func _test_cleanup(form: StringName) -> void:
	var combat: CombatController = _actor.combat
	var hand := Transform2D(0.0, Vector2(8.0, -24.0))
	for state: StringName in [&"idle", &"dash", &"hurt", &"dead"]:
		combat.attack = combat.tuning.find_attack(&"light_1")
		combat.state = &"attack"
		combat.elapsed = combat.attack.windup * combat.time_scale_for_form()
		_vine.sample_combat(combat, form, hand)
		combat.state = state
		_vine.sample_combat(combat, form, hand)
		_expect(not _vine.visible, "%s %s interrupts the vine immediately" % [form, state])
		_expect(_vine.sampled_animation.is_empty(), "%s %s clears the previous action identity" % [form, state])
		_expect(_vine._trail_shapes.is_empty(), "%s %s removes every previous trail sample" % [form, state])
	combat.state = &"attack"
	combat.attack = combat.tuning.find_attack(&"light_1")
	_vine.sample_combat(combat, form, hand)
	combat.cancel()
	_vine.sample_combat(combat, form, hand)
	_expect(not _vine.visible, String(form) + " cancel clears the active vine")
	combat.state = &"attack"
	combat.attack = combat.tuning.find_attack(&"light_1")
	_vine.sample_combat(combat, &"sprout", hand)
	_expect(not _vine.visible, "Sprout form never retains combat vine visuals")

func _test_player_attachment(form: StringName) -> void:
	_actor.combat.reset()
	_actor.form_controller.restore_form(form)
	var integrated: VineWhipVisual = _find_vine(_actor.visuals)
	_expect(integrated != null, String(form) + " production Player instantiates VineWhipVisual")
	if integrated == null:
		return
	for facing: float in [1.0, -1.0]:
		_actor.combat.state = &"attack"
		_actor.combat.attack = _actor.combat.tuning.find_attack(&"heavy")
		_actor.combat.facing = facing
		_actor.combat.elapsed = _actor.combat.attack.windup * _actor.combat.time_scale_for_form()
		_actor.visuals.set_combat_state(_actor.combat)
		_actor.visuals._spine_visual.spine_sprite.update_skeleton(0.0)
		var point: Vector2 = _actor.visuals.to_local(_actor.visuals._spine_visual.combat_hand_global_transform().origin)
		_expect(integrated.position.distance_to(point) < 0.02, "%s facing %s attaches after this frame's Spine pose" % [form, facing])
	_actor.combat.cancel()
	_actor.visuals.set_combat_state(_actor.combat)
	_expect(not integrated.visible, String(form) + " Player propagates cancellation in the same update")
	_actor.form_controller.restore_form(&"sprout")
	_expect(not integrated.visible, "Form replacement clears the old attachment")

func _test_frozen_clock() -> void:
	_actor.form_controller.restore_form(&"mature")
	_actor.combat.state = &"attack"
	_actor.combat.attack = _actor.combat.tuning.find_attack(&"heavy")
	_actor.combat.elapsed = _actor.combat.attack.windup * _actor.combat.time_scale_for_form() * 0.6
	_vine.sample_combat(_actor.combat, &"mature", Transform2D.IDENTITY)
	var tip: Vector2 = _vine.tip_position
	var phase: float = _vine.sampled_phase
	for frame: int in range(4):
		await process_frame
	_expect(_vine.tip_position.distance_to(tip) < 0.001 and is_equal_approx(phase, _vine.sampled_phase), "Rendering frames without combat elapsed do not advance animation or hitstop")

func _bones_are_finite(node: Node) -> bool:
	if node is Bone2D and not (node as Bone2D).transform.is_finite():
		return false
	for child: Node in node.get_children():
		if not _bones_are_finite(child):
			return false
	return true

func _leaf_scales(node: Node) -> Dictionary:
	var scales: Dictionary = {}
	if node is Sprite2D and String(node.name).begins_with("Leaf"):
		scales[String(node.name)] = (node as Sprite2D).global_scale.abs()
	for child: Node in node.get_children():
		scales.merge(_leaf_scales(child))
	return scales

func _find_vine(node: Node) -> VineWhipVisual:
	if node is VineWhipVisual:
		return node as VineWhipVisual
	for child: Node in node.get_children():
		var found: VineWhipVisual = _find_vine(child)
		if found != null:
			return found
	return null

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _test_parry_sweep(form: StringName) -> void:
	_actor.form_controller.restore_form(form)
	var combat := _actor.combat
	var vine := _find_vine(_actor.visuals)
	var spine := _actor.visuals._spine_visual
	for facing: float in [-1.0, 1.0]:
		combat.reset()
		combat.facing = facing
		combat.state = &"parry"
		for frame: int in range(1, 7):
			combat.elapsed = frame / 60.0
			_actor.visuals.set_combat_state(combat)
			spine.spine_sprite.update_skeleton(0.0)
		_expect(vine.visible, "Deflection extends the solid vine before contact")
		var caught: PackedVector2Array = vine.chain_world_points()
		combat.parry_from_progress = combat.progress()
		combat.state = &"parry_success"
		combat.elapsed = 0.0
		_actor.visuals.set_combat_state(combat)
		spine.spine_sprite.update_skeleton(0.0)
		var continued: PackedVector2Array = vine.chain_world_points()
		for index: int in range(caught.size()):
			_expect(caught[index].distance_to(continued[index]) < 0.03, "Successful sweep continues the caught vine without teleporting")
		var tips := PackedVector2Array()
		for frame: int in range(1, 16):
			combat.elapsed = frame / 60.0
			_actor.visuals.set_combat_state(combat)
			spine.spine_sprite.update_skeleton(0.0)
			var points: PackedVector2Array = vine.chain_world_points()
			_expect(points.size() == 10, "The sweeping vine remains a continuous ten-joint chain")
			if points.is_empty(): continue
			var hand := spine.combat_hand_global_transform()
			_expect(points[0].distance_to(hand.origin) < 0.03, "Whole-body deflection keeps the vine pinned to the actual wrist")
			_expect((points[1] - points[0]).normalized().dot(hand.x.normalized()) > 0.999, "The vine leaves the hand along its wrist tangent")
			_expect(vine._trail_shapes.is_empty(), "Deflection has no luminous trails")
			_expect(combat.attack == null, "The enlarged vine does not create an attack damage hitbox")
			tips.append(points[9])
			spine.spine_sprite.update_skeleton(0.0)
			_expect(points[9].distance_to(vine.chain_world_points()[9]) < 0.01, "Repeated paused samples cannot move the sweep")
		var travel: float = 0.0
		for point: Vector2 in tips:
			travel = maxf(travel, point.distance_to(tips[0]))
		_expect(travel > 24.0, "Deflection has a substantial visible sweeping arc")
		combat.elapsed = combat.tuning.parry_success_duration
		_actor.visuals.set_combat_state(combat)
		spine.spine_sprite.update_skeleton(0.0)
		_expect(not vine.visible, "The vine retracts completely as the deflection ends")
		combat.cancel()
		_actor.visuals.set_combat_state(combat)
		_expect(vine.chain_world_points().is_empty(), "Cancelling deflection clears the chain immediately")
