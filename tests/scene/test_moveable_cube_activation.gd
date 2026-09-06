extends SceneTree

const CUBE_SCENE: PackedScene = preload("res://features/level/moveable_cube.tscn")
const BUTTON_SCENE: PackedScene = preload("res://features/level/handbuilt/trigger_button.tscn")
const EVENT_BUS_SCENE: PackedScene = preload("res://features/level/level_event_bus.tscn")
const DOOR_SCENE: PackedScene = preload("res://features/level/whitebox_door.tscn")
const MOTION_FRAME_LIMIT: int = 180

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_directions()
	await _test_local_direction()
	await _test_latch_and_reset()
	await _test_rejected_activation_retry()
	await _test_button_contact()
	await _test_door_compatibility()
	await _test_artwork_shake_and_stop()
	if _failures == 0:
		print("PASS: cube activation directions, normalization, latch/reset, retries, button contact, door compatibility and artwork shake")
	else:
		push_error("MoveableCube activation checks failed: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_directions() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(3.0, -4.0)]
	for direction: Vector2 in directions:
		var cube := _make_cube()
		cube.position = Vector2(100.0, 150.0)
		cube.movement_direction = direction
		stage.add_child(cube)
		await _frames(2)
		var start: Vector2 = cube.global_position
		_check(cube.activate(), "A valid direction must start movement: %s" % direction)
		await _wait_for_motion(cube)
		_check(cube.global_position.distance_to(start + direction.normalized() * cube.move_distance) < 0.02,
			"Direction %s must reach its normalized endpoint." % direction)
		_check(is_equal_approx(cube.global_position.distance_to(start), cube.move_distance),
			"Direction magnitude must not change the configured travel distance.")
		cube.queue_free()
		await _frames(2)
	stage.queue_free()
	await _frames(2)


func _test_local_direction() -> void:
	var stage := Node2D.new()
	stage.position = Vector2(320.0, 180.0)
	stage.rotation = 0.43
	root.add_child(stage)
	var cube := _make_cube()
	cube.position = Vector2(35.0, 55.0)
	cube.rotation = 0.28
	cube.movement_direction = Vector2(0.0, -7.0)
	stage.add_child(cube)
	await _frames(2)
	var target: Vector2 = cube.to_global(Vector2.UP * cube.move_distance)
	var original_rotation: float = cube.global_rotation
	_check(cube.activate(), "A rotated cube must activate.")
	await _wait_for_motion(cube)
	_check(cube.global_position.distance_to(target) < 0.02, "Movement must respect both parent and cube local rotation.")
	_check(is_equal_approx(cube.global_rotation, original_rotation), "Directional translation must preserve rotation.")
	stage.queue_free()
	await _frames(2)


func _test_latch_and_reset() -> void:
	var cube := _make_cube()
	cube.position = Vector2(200.0, 200.0)
	cube.rotation = 0.3
	cube.cube_size = Vector2(24.0, 36.0)
	root.add_child(cube)
	await _frames(2)
	var original_transform: Transform2D = cube.global_transform
	var original_size: Vector2 = cube.cube_size
	var starts: Array[int] = [0]
	var completions: Array[int] = [0]
	cube.motion_started.connect(func(_moving_cube: MoveableCube) -> void:
		starts[0] += 1
		_check(not cube.activate(), "A motion_started listener must not activate the cube twice.")
	)
	cube.motion_completed.connect(func(_moving_cube: MoveableCube) -> void: completions[0] += 1)
	_check(cube.activate() and cube.is_activated(), "Accepted activation must latch immediately.")
	_check(not cube.activate(), "Repeated activation during motion must be rejected.")
	await _wait_for_motion(cube)
	_check(not cube.activate() and cube.is_activated(), "Completed activation must stay latched.")
	_check(starts[0] == 1 and completions[0] == 1, "A one-shot activation must emit each motion signal once.")
	_check(cube.move_to_rect(Rect2(280.0, 260.0, 48.0, 52.0)), "The explicit rectangle movement API must remain usable.")
	await _wait_for_motion(cube)
	cube.reset_platform()
	await _frames(2)
	_check(not cube.is_activated() and not cube.is_moving(), "Reset must clear activation and motion state.")
	_check(cube.global_transform.is_equal_approx(original_transform) and cube.cube_size.is_equal_approx(original_size),
		"Reset must restore the original pose and size after explicit movement.")
	_check(cube.activate(), "Reset must permit a fresh activation.")
	await _frames(2)
	cube.reset_platform()
	await _frames(2)
	_check(not cube.is_moving() and cube.global_transform.is_equal_approx(original_transform),
		"Reset during motion must cancel travel and restore the original pose.")
	cube.queue_free()
	await _frames(2)


func _test_rejected_activation_retry() -> void:
	var cube := _make_cube()
	_check(not cube.activate() and not cube.is_activated(), "Activation before ready must not consume the one-shot.")
	root.add_child(cube)
	await _frames(2)
	cube.movement_direction = Vector2.ZERO
	_check(not cube.activate() and not cube.is_activated(), "Zero direction must reject without latching.")
	cube.movement_direction = Vector2.RIGHT
	cube.move_distance = 0.0
	_check(not cube.activate() and not cube.is_activated(), "Zero distance must reject without latching.")
	cube.move_distance = 48.0
	_check(cube.move_top_left_to(Vector2(0.0, 32.0)), "The explicit translation API must still start motion.")
	_check(not cube.activate() and not cube.is_activated(), "Busy rejection must preserve the activation opportunity.")
	await _wait_for_motion(cube)
	var target: Vector2 = cube.global_position + Vector2.RIGHT * cube.move_distance
	_check(cube.activate(), "Activation must be retryable after invalid configuration or busy rejection.")
	await _wait_for_motion(cube)
	_check(cube.global_position.distance_to(target) < 0.02, "Retried activation must move from the current position.")
	cube.queue_free()
	await _frames(2)


func _test_button_contact() -> void:
	var stage := Node2D.new()
	stage.add_child(EVENT_BUS_SCENE.instantiate())
	root.add_child(stage)
	var cube := _make_cube()
	cube.name = "Cube"
	cube.position = Vector2(240.0, 160.0)
	cube.movement_direction = Vector2.UP
	cube.activation_event = &"raise_cube"
	stage.add_child(cube)
	var button := BUTTON_SCENE.instantiate() as TriggerButton
	button.position = Vector2(80.0, 160.0)
	button.event_id = &"raise_cube"
	stage.add_child(button)
	var presses: Array[int] = [0]
	button.pressed.connect(func(_button: TriggerButton, _actor: Node2D) -> void: presses[0] += 1)
	var actor := CharacterBody2D.new()
	actor.collision_layer = 2
	actor.collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8.0, 8.0)
	collider.shape = shape
	actor.add_child(collider)
	actor.position = button.position + Vector2(8.0, 8.0)
	stage.add_child(actor)
	await _frames(4)
	_check(not button.is_pressed() and not cube.is_activated(), "A body outside the player group must not press the button.")
	actor.position = Vector2.ZERO
	await _frames(3)
	actor.add_to_group(&"player")
	actor.position = button.position + Vector2(8.0, 8.0)
	await _frames(4)
	_check(button.is_pressed() and cube.is_activated(), "Real player-group body overlap must activate the cube through the level event bus.")
	await _wait_for_motion(cube)
	_check(cube.position.distance_to(Vector2(240.0, 112.0)) < 0.02, "The button event must use the cube's configured direction.")
	actor.position = Vector2.ZERO
	await _frames(3)
	actor.position = button.position + Vector2(8.0, 8.0)
	await _frames(4)
	_check(presses[0] == 1 and not cube.is_moving(), "Repeated player overlap must not restart a one-shot cube.")
	stage.queue_free()
	await _frames(2)


func _test_door_compatibility() -> void:
	var door := DOOR_SCENE.instantiate() as WhiteboxDoor
	door.position = Vector2(400.0, 200.0)
	door.startup_shake_duration = 0.0
	door.motion_speed = 720.0
	door.open_offset = Vector2(0.0, -32.0)
	door.movement_direction = Vector2.RIGHT
	door.move_distance = 96.0
	root.add_child(door)
	await _frames(2)
	_check(door.activate() and door.is_activated(), "Door activation must use its existing open behavior.")
	await _wait_for_motion(door)
	_check(door.is_open() and door.position.distance_to(Vector2(400.0, 168.0)) < 0.02,
		"Door activation must respect open_offset rather than the inherited cube direction.")
	_check(not door.activate() and not door.open(), "Both door command APIs must share one activation latch.")
	door.reset_platform()
	await _frames(2)
	_check(not door.is_open() and not door.is_activated(), "Reset must clear the door's opened and activated states.")
	_check(door.open(), "The original door open API must still work after reset.")
	await _wait_for_motion(door)
	_check(door.is_open(), "Door completion must still mark the door open after reset.")
	door.queue_free()
	await _frames(2)


func _test_artwork_shake_and_stop() -> void:
	var cube := _make_cube()
	cube.position = Vector2(500.0, 300.0)
	cube.startup_shake_duration = 0.4
	cube.startup_shake_distance = 4.0
	cube.art_texture = GradientTexture2D.new()
	cube.art_offset = Vector2(3.0, 5.0)
	root.add_child(cube)
	await _frames(2)
	var artwork := cube.get_node("Artwork") as Sprite2D
	var initial_position: Vector2 = cube.global_position
	_check(cube.activate(), "A textured cube must activate.")
	var saw_shake: bool = false
	for _step: int in range(8):
		await physics_frame
		saw_shake = saw_shake or artwork.position.distance_to(cube.art_offset) > 0.01
	_check(saw_shake, "Startup shake must visibly offset configured artwork.")
	_check(cube.global_position.is_equal_approx(initial_position), "Startup shake must not move the physics body.")
	cube.stop_at_target()
	await _frames(2)
	_check(not cube.is_moving() and cube.global_position.distance_to(initial_position + Vector2.RIGHT * cube.move_distance) < 0.02,
		"Stopping during startup must place the cube at the activation endpoint.")
	_check(artwork.position.is_equal_approx(cube.art_offset), "Stopping during startup must clear the artwork shake offset.")
	cube.queue_free()
	await _frames(2)


func _make_cube() -> MoveableCube:
	var cube := CUBE_SCENE.instantiate() as MoveableCube
	cube.startup_shake_duration = 0.0
	cube.motion_speed = 720.0
	cube.move_distance = 48.0
	return cube


func _wait_for_motion(cube: MoveableCube) -> void:
	for _step: int in range(MOTION_FRAME_LIMIT):
		if not cube.is_moving():
			await _frames(2)
			return
		await physics_frame
	_check(false, "Motion did not finish within %d physics frames." % MOTION_FRAME_LIMIT)
	cube.stop_at_target()
	await _frames(2)


func _frames(count: int) -> void:
	for _step: int in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
