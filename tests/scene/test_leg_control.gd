extends SceneTree
## Exercises the shipped player and absorption components, without a playable test level.
const STEP := 1.0 / 60.0
var _player: Player
var _failures: PackedStringArray = []

func _init() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("_run")

func _run() -> void:
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 20.0)
	collision.shape = shape
	floor_body.position.y = 10.0
	floor_body.add_child(collision)
	root.add_child(floor_body)
	_player = preload("res://features/player/player.tscn").instantiate() as Player
	root.add_child(_player)
	_player.set_physics_process(false)
	await _reset(&"sprout")
	var tank := preload("res://features/level/nutrition_tank.tscn").instantiate() as NutritionTank
	root.add_child(tank)
	tank.set_physics_process(false)
	tank._on_body_entered(_player)
	Input.action_press(&"absorb_resource")
	for frame: int in range(390):
		tank._physics_process(STEP)
	_expect(_player.current_form_id() == &"humanoid", "E absorption must enter humanoid and stop at one stage")
	_press_primary()
	_expect(_player.abilities.is_rooted(), "Q after absorption must enter rooted mode")
	Input.action_release(&"absorb_resource")
	await _test_full_extension(&"move_right")
	await _reset()
	_press_primary()
	await _test_full_extension(&"move_left")
	await _reset()
	_press_primary()
	await _test_full_extension(&"move_up")
	await _test_short_corner()
	await _test_cancel_and_transform()
	tank.free()
	_player.free()
	floor_body.free()
	await process_frame
	await create_timer(0.1).timeout
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: absorption, leg speed, held limits, facing, corner retraction and cancellation")
	quit(0 if _failures.is_empty() else 1)

func _test_full_extension(action: StringName) -> void:
	var anchor := _player.global_position
	_set_direction(action)
	await _steps(90)
	_expect(absf(_player.abilities.get_leg_length() - _player.abilities.get_max_leg_length()) < 0.1, "%s: reach full extension in 1.5 seconds" % action)
	var limit_position := _player.global_position
	var facing: float = _player.visuals.animation_machine.get("_facing")
	var max_drift := 0.0
	var flipped := false
	for frame: int in range(90):
		await _steps(1)
		max_drift = maxf(max_drift, _player.global_position.distance_to(limit_position))
		flipped = flipped or not is_equal_approx(_player.visuals.animation_machine.get("_facing"), facing)
	_expect(max_drift < 0.05, "%s: holding at the limit must not move or twitch (drift %.3f)" % [action, max_drift])
	_expect(not flipped, "%s: holding at the limit must not flip facing" % action)
	_set_direction()
	var retract_frames := 0
	while _player.abilities.is_leg_extended() and retract_frames < 360:
		await _steps(1)
		retract_frames += 1
	_expect(retract_frames <= 60, "%s: full retraction should finish within one second, took %.3f s" % [action, retract_frames * STEP])
	_expect(_player.global_position.distance_to(anchor) < 2.1, "%s: retract to the fixed root" % action)
	_expect(_player.abilities.is_rooted(), "Retraction must retain rooted mode")
	var stopped := _player.global_position
	await _steps(20)
	_expect(_player.global_position.distance_to(stopped) < 0.05, "Finishing retraction must clear residual movement")
	print("MEASURE %s limit drift=%.4f retract=%.3fs" % [action, max_drift, retract_frames * STEP])

func _test_short_corner() -> void:
	await _reset()
	_press_primary()
	_set_direction(&"move_right")
	await _steps(20)
	_set_direction(&"move_up")
	await _steps(20)
	_set_direction(&"move_left")
	await _steps(1)
	_expect(_player.abilities.get_leg_path().size() == 4, "Two turns must create two fixed corners")
	_set_direction()
	var skipped := false
	var diagonal := false
	for frame: int in range(180):
		var before := _world_path()
		await _steps(1)
		var after := _world_path()
		if after.size() < before.size() and before.size() > 2:
			skipped = skipped or before.size() - after.size() > 1 or _player.global_position.distance_to(before[1]) > 2.1
		for index: int in range(after.size() - 1):
			var segment := after[index + 1] - after[index]
			diagonal = diagonal or (absf(segment.x) > 0.1 and absf(segment.y) > 0.1)
		if not _player.abilities.is_leg_extended():
			break
	_expect(not skipped, "Retraction must visit every corner once, including a final segment shorter than two pixels")
	_expect(not diagonal, "Retracting a right-angled path must not replace it with a diagonal")
	_expect(not _player.abilities.is_leg_extended(), "Bent leg should completely retract")

func _test_cancel_and_transform() -> void:
	for destination: StringName in [&"none", &"mature", &"sprout"]:
		await _reset()
		_press_primary()
		_set_direction(&"move_up")
		await _steps(20)
		_set_direction(&"move_right")
		await _steps(12)
		_set_direction()
		if destination == &"none":
			_press_primary()
		else:
			Input.action_press(&"absorb_resource")
			if destination == &"mature":
				_player.absorb_nutrition(1000.0)
			else:
				_player.absorb_toxin(1000.0)
			_expect(_player.current_form_id() == destination, "Absorption must transform during leg extension")
			Input.action_release(&"absorb_resource")
		_expect(not _player.abilities.is_rooted() and not _player.abilities.is_leg_extended(), "Unrooting or transforming must cancel all leg state")
		_expect(_player.abilities.get_leg_path().size() == 1, "Cancelled leg must leave no path")
		_expect(_player.velocity.is_zero_approx(), "Cancelled leg must not impart movement to the next mode")
		var stopped_x := _player.global_position.x
		await _steps(45)
		_expect(absf(_player.global_position.x - stopped_x) < 0.05, "After cancellation only gravity may move an idle body")
		_set_direction(&"move_right")
		await _steps(12)
		_set_direction()
		await _steps(20)
		_expect(is_zero_approx(_player.velocity.x), "Normal walking must still brake after cancelling legs")

func _world_path() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in _player.abilities.get_leg_path():
		result.append(_player.to_global(point))
	return result

func _reset(form_id: StringName = &"humanoid") -> void:
	_set_direction()
	Input.action_release(&"absorb_resource")
	_player.cancel_actions()
	_player.form_controller.restore_form(form_id)
	_player.global_position = Vector2(0.0, -1.0)
	_player.velocity = Vector2.ZERO
	await _steps(12)
	_expect(_player.is_on_floor(), "Fixture must settle on the floor")

func _steps(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		_player._physics_process(STEP)

func _set_direction(action: StringName = &"") -> void:
	for direction: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(direction)
	if not action.is_empty():
		Input.action_press(action)

func _press_primary() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	_player._unhandled_input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition and not message in _failures:
		_failures.append(message)
