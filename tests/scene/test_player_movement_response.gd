extends SceneTree
## Measures the real player on the authoritative main level's floor.

const MAIN_SCENE: PackedScene = preload("res://scenes/app/main.tscn")
const FORM_SPEEDS: Dictionary = {&"sprout": 240.0, &"humanoid": 240.0, &"mature": 240.0}
const STEP: float = 1.0 / 60.0

var _player: Player
var _failures: PackedStringArray = []


func _init() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	_player = main.get_node("LevelHost/LevelMain/Level01/Actors/Player") as Player
	_player.set_physics_process(false)
	for form_id: StringName in FORM_SPEEDS:
		for direction: float in [-1.0, 1.0]:
			await _test_ground_response(form_id, direction)
	await _test_air_control()
	await _test_absorption_transitions()
	await _test_matching_air_response()
	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if _failures.is_empty():
		print("PASS: main-level movement, matching three-form response, seamless absorption transitions and matching jumps")
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_ground_response(form_id: StringName, direction: float) -> void:
	await _place_on_floor(form_id)
	var speed: float = FORM_SPEEDS[form_id]
	var start_frames := await _accelerate(direction, speed)
	_expect(start_frames * STEP <= 0.10, "%s: ground start should reach full speed within 100 ms" % form_id)
	_expect(is_equal_approx(absf(_player.velocity.x), speed), "%s: use the common movement speed" % form_id)

	var stop_start_x := _player.position.x
	var stop_frames := 0
	while not is_zero_approx(_player.velocity.x) and stop_frames < 60:
		await _step(0.0)
		stop_frames += 1
	var stop_distance := absf(_player.position.x - stop_start_x)
	_expect(stop_frames * STEP <= 0.10, "%s: releasing movement should stop within 100 ms" % form_id)
	_expect(stop_distance <= 6.1, "%s: releasing movement should travel at most 6 world pixels" % form_id)
	var stopped_x := _player.position.x
	for _frame: int in range(6):
		await _step(0.0)
	_expect(is_equal_approx(_player.position.x, stopped_x), "%s: the player should stay still after braking" % form_id)

	await _accelerate(direction, speed)
	var turn_frames := 0
	while _player.velocity.x * direction > 0.0 and turn_frames < 60:
		await _step(-direction)
		turn_frames += 1
	_expect(turn_frames * STEP <= 0.08, "%s: opposite input should cancel forward momentum within 80 ms" % form_id)
	await _accelerate(-direction, speed)
	_expect(is_equal_approx(_player.velocity.x, -direction * speed), "%s: reversal should reach the opposite top speed" % form_id)
	print("MEASURE %s dir=%+.0f start=%.3fs stop=%.3fs drift=%.2fpx turn=%.3fs" % [form_id, direction, start_frames * STEP, stop_frames * STEP, stop_distance, turn_frames * STEP])


func _test_air_control() -> void:
	for form_id: StringName in [&"humanoid", &"mature"]:
		await _place_on_floor(form_id)
		var speed: float = FORM_SPEEDS[form_id]
		await _accelerate(1.0, speed)
		_player.movement.request_jump()
		await _step(0.0, true)
		_expect(not _player.is_on_floor() and _player.velocity.y < 0.0, "%s: jumping must still leave the floor" % form_id)
		_expect(is_equal_approx(_player.velocity.x, speed - 3600.0 * STEP), "%s: use the same braking from the takeoff frame" % form_id)
		var previous_x_speed := _player.velocity.x
		await _step(-1.0, true)
		_expect(is_equal_approx(_player.velocity.x, previous_x_speed - 4800.0 * STEP), "%s: use the same reversal response in the air" % form_id)
		var rise_speed := _player.velocity.y
		_player.movement.release_jump()
		_expect(is_equal_approx(_player.velocity.y, rise_speed * 0.5), "%s: releasing jump must still cut the upward speed" % form_id)


func _place_on_floor(form_id: StringName) -> void:
	_player.cancel_actions()
	_player.form_controller.restore_form(form_id)
	# Use the clear nursery floor between the sprout tunnel and root practice ledge.
	# Reposition only the test fixture; gameplay movement always uses the controller.
	_player.position = Vector2(400.0, 400.0)
	_player.velocity = Vector2.ZERO
	for _frame: int in range(60):
		await _step(0.0)
		if _player.is_on_floor():
			break
	_expect(_player.is_on_floor(), "The main-level player must settle on the nursery floor")


func _accelerate(direction: float, speed: float) -> int:
	var frames := 0
	while not is_equal_approx(_player.velocity.x, direction * speed) and frames < 60:
		await _step(direction)
		frames += 1
	return frames


func _step(direction: float, jump_held: bool = false) -> void:
	await physics_frame
	_player.movement.tick(STEP, direction, jump_held)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_absorption_transitions() -> void:
	for direction: float in [-1.0, 1.0]:
		await _place_on_floor(&"sprout")
		_player.resources.reset()
		await _accelerate(direction, 240.0)
		for next_form: StringName in [&"humanoid", &"mature", &"humanoid", &"sprout"]:
			var previous_velocity := _player.velocity
			if _player.current_form_id() == &"sprout" or next_form == &"mature":
				_player.absorb_nutrition(_player.form_controller.get_current().growth_threshold)
			else:
				_player.absorb_toxin(_player.resources.toxin_threshold())
			_expect(_player.current_form_id() == next_form, "Absorption must reach %s" % next_form)
			_expect(_player.velocity.is_equal_approx(previous_velocity), "Changing to %s must preserve walking momentum" % next_form)
			await _step(direction)
			_expect(is_equal_approx(_player.velocity.x, direction * 240.0), "Changing to %s must not cause a speed surge or restart" % next_form)
		await _step(0.0)
		_expect(is_equal_approx(_player.velocity.x, direction * 180.0), "The last transformation must still use the common braking response")

	# Transform while still accelerating, then again while rising through a jump.
	await _place_on_floor(&"sprout")
	_player.resources.reset()
	await _step(1.0)
	await _step(1.0)
	var partial_speed := _player.velocity.x
	_player.absorb_nutrition(100.0)
	_expect(is_equal_approx(_player.velocity.x, partial_speed), "Growth must not reset a partial run-up")
	await _step(1.0)
	_expect(is_equal_approx(_player.velocity.x, partial_speed + 40.0), "Growth must continue the same acceleration curve")
	_player.movement.request_jump()
	await _step(1.0)
	var rising_velocity := _player.velocity
	_player.absorb_nutrition(120.0)
	_expect(_player.current_form_id() == &"mature" and _player.velocity.is_equal_approx(rising_velocity), "Growing in midair must preserve the jump and horizontal velocity")
	await _step(1.0)
	_expect(is_equal_approx(_player.velocity.y, rising_velocity.y + 1200.0 * STEP), "Growing in midair must preserve ordinary gravity")


func _test_matching_air_response() -> void:
	var falling_reference: Array[Vector2] = []
	for form_id: StringName in FORM_SPEEDS:
		await _place_on_floor(form_id)
		_player.position = Vector2(400.0, 200.0)
		_player.velocity = Vector2.ZERO
		await _step(0.0)
		for frame: int in range(24):
			var direction := 1.0 if frame < 6 else (0.0 if frame < 12 else -1.0)
			await _step(direction)
			_expect(not _player.is_on_floor(), "Air response fixture must remain airborne")
			if form_id == &"sprout":
				falling_reference.append(_player.velocity)
			else:
				_expect(_player.velocity.is_equal_approx(falling_reference[frame]), "%s: airborne acceleration, stopping and turning must match the sprout at frame %d" % [form_id, frame])

	var jump_reference: Array[Vector2] = []
	for form_id: StringName in [&"humanoid", &"mature"]:
		await _place_on_floor(form_id)
		_player.movement.request_jump()
		for frame: int in range(50):
			# No held-jump glide: this compares the normal jump and landing arc.
			await _step(0.0)
			if form_id == &"humanoid":
				jump_reference.append(_player.velocity)
			else:
				_expect(_player.velocity.is_equal_approx(jump_reference[frame]), "Ordinary mature jump must match humanoid at frame %d" % frame)
		_expect(_player.is_on_floor(), "%s: the ordinary jump must land" % form_id)
