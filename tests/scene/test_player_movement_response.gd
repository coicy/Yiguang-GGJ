extends SceneTree
## Measures the real player on the authoritative main level's floor.

const MAIN_SCENE: PackedScene = preload("res://scenes/app/main.tscn")
const FORM_SPEEDS: Dictionary = {&"sprout": 220.0, &"humanoid": 300.0, &"mature": 260.0}
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
	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if _failures.is_empty():
		print("PASS: main-level movement, three form speeds, braking, reversal and air control")
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_ground_response(form_id: StringName, direction: float) -> void:
	await _place_on_floor(form_id)
	var speed: float = FORM_SPEEDS[form_id]
	var start_frames := await _accelerate(direction, speed)
	_expect(start_frames * STEP <= 0.15, "%s: ground start should reach full speed within 150 ms" % form_id)
	_expect(is_equal_approx(absf(_player.velocity.x), speed), "%s: keep the form's original top speed" % form_id)

	var stop_start_x := _player.position.x
	var stop_frames := 0
	while not is_zero_approx(_player.velocity.x) and stop_frames < 60:
		await _step(0.0)
		stop_frames += 1
	var stop_distance := absf(_player.position.x - stop_start_x)
	_expect(stop_frames * STEP <= 0.10, "%s: releasing movement should stop within 100 ms" % form_id)
	_expect(stop_distance <= 12.0, "%s: releasing movement should travel at most 12 world pixels" % form_id)
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
		_expect(is_equal_approx(_player.velocity.x, speed - 800.0 * STEP), "%s: use the original air braking from the takeoff frame" % form_id)
		var previous_x_speed := _player.velocity.x
		await _step(-1.0, true)
		_expect(is_equal_approx(_player.velocity.x, previous_x_speed - 1200.0 * STEP), "%s: retain the original air steering instead of ground turn acceleration" % form_id)
		var rise_speed := _player.velocity.y
		_player.movement.release_jump()
		_expect(is_equal_approx(_player.velocity.y, rise_speed * 0.5), "%s: releasing jump must still cut the upward speed" % form_id)


func _place_on_floor(form_id: StringName) -> void:
	_player.cancel_actions()
	_player.form_controller.restore_form(form_id)
	# Reposition only the test fixture; gameplay movement always uses the controller.
	_player.position = Vector2(300.0, 400.0)
	_player.velocity = Vector2.ZERO
	for _frame: int in range(60):
		await _step(0.0)
		if _player.is_on_floor():
			break
	_expect(_player.is_on_floor(), "The main-level player must settle on StartFloor")


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
