extends SceneTree

const LEVEL_SCENE_PATH: String = "res://scenes/levels/Level_main.tscn"
var player: Player
var camera: Camera2D
var framing: Node

class FallDriver extends Node:
	var target: Player
	var ticks: int = 0
	var elapsed: float = 0.0

	func _physics_process(delta: float) -> void:
		if ticks >= 13:
			return
		target.velocity.y = 900.0
		target.global_position.y += 900.0 * delta
		elapsed += delta
		ticks += 1

class FallSampler extends Node:
	var driver: FallDriver
	var camera: Camera2D
	var samples: int = 0
	var maximum_ratio: float = 0.0

	func _physics_process(_delta: float) -> void:
		if samples == driver.ticks:
			return
		camera.force_update_scroll()
		var target: Player = driver.target
		var screen: Vector2 = target.get_viewport().get_canvas_transform() * target.global_position
		var ratio: float = screen.y / camera.get_viewport_rect().size.y
		maximum_ratio = maxf(maximum_ratio, ratio)
		assert(ratio > 0.0 and ratio < 0.85)
		samples = driver.ticks

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(55.0).timeout.connect(func() -> void: push_error("Camera regression timeout"); quit(1))
	var scene := (load(LEVEL_SCENE_PATH) as PackedScene).instantiate() as Node2D
	root.add_child(scene)
	await physics_frame
	var level := scene.get_node("Level01")
	player = level.get_node("%Player") as Player
	camera = player.get_node("Camera2D") as Camera2D
	framing = level.get_node("%ForwardCameraFraming")
	# This test owns the generic controller contract; production region constraints
	# and their deliberate 80%/45% exceptions are covered by test_camera_regions.
	framing.regions_enabled = false
	var phantom := level.get_node("%PhantomCamera2D") as PhantomCamera2D
	var bounds := level.get_node("%CameraBounds") as CameraBounds
	assert(camera.get_node("PhantomCameraHost") != null)
	assert(not phantom.follow_damping)
	assert(not phantom.lookahead)
	# Independently transform all four authored corners; do not call get_world_rect.
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(bounds.bounds_size.x, 0), bounds.bounds_size, Vector2(0, bounds.bounds_size.y)]
	var world_rect := Rect2(bounds.to_global(corners[0]), Vector2.ZERO)
	for corner: Vector2 in corners:
		world_rect = world_rect.expand(bounds.to_global(corner))
	assert(phantom.limit_left == int(world_rect.position.x))
	assert(phantom.limit_right == int(world_rect.end.x))
	assert(phantom.limit_top == int(world_rect.position.y))
	assert(phantom.limit_bottom == int(world_rect.end.y))
	player.set_physics_process(false)
	player.global_position = world_rect.get_center()
	framing.reset_for_respawn(1.0)
	await _frames(50)
	_assert_ratio(Vector2(0.2, 0.45))
	# Accepted intent comes from actual production input for one player tick.
	await _accept_input("move_left")
	await _frames(2)
	assert(framing.get_facing_direction() == 1.0, "Brief reverse input must not flip the camera")
	await _accept_input("")
	await _frames(10)
	_assert_ratio(Vector2(0.2, 0.45))
	await _accept_input("move_left")
	await _frames(9)
	assert(framing.get_facing_direction() == -1.0)
	var turning: float = _ratio().x
	assert(turning > 0.2 and turning < 0.8)
	await _frames(80)
	_assert_ratio(Vector2(0.8, 0.45))
	await _accept_input("")
	player.velocity.x = 500.0
	await _frames(15)
	_assert_ratio(Vector2(0.8, 0.45))
	# Rapid alternating accepted input must retain the established direction.
	for action: String in ["move_right", "move_left", "move_right", "move_left"]:
		await _accept_input(action)
		await _frames(2)
		assert(framing.get_facing_direction() == -1.0)
	await _accept_input("")
	phantom.zoom = Vector2(2, 2)
	await _frames(60)
	_assert_ratio(Vector2(0.8, 0.45))
	var original_size: Vector2i = root.size
	root.size = Vector2i(1000, 600)
	await _frames(60)
	_assert_ratio(Vector2(0.8, 0.45))
	root.size = original_size
	phantom.zoom = Vector2(3, 3)
	player.global_position = world_rect.get_center()
	await _frames(60)
	var before: float = camera.get_screen_center_position().y
	player.global_position.y += 2.0
	await _frames(1)
	assert(camera.get_screen_center_position().y > before + 0.01)
	# Drive every physics tick before framing; sample after the actual camera host.
	# Neither motion nor measurement depends on the number of rendered frames.
	var fall_start: float = player.global_position.y
	var driver := FallDriver.new()
	driver.target = player
	driver.process_physics_priority = 100
	var sampler := FallSampler.new()
	sampler.driver = driver
	sampler.camera = camera
	sampler.process_physics_priority = 400
	root.add_child(driver)
	root.add_child(sampler)
	while driver.ticks < 13:
		await physics_frame
		await process_frame
	assert(sampler.samples == 13)
	var fall_speed: float = (player.global_position.y - fall_start) / driver.elapsed
	assert(absf(fall_speed - 900.0) < 0.01, "Fixture must fall at 900px/s of physics time")
	var maximum_ratio: float = sampler.maximum_ratio
	driver.queue_free()
	sampler.queue_free()
	player.velocity = Vector2.ZERO
	await _frames(60)
	_assert_ratio(Vector2(0.8, 0.45))
	# Keep the entire body inside authored bounds, even at the clamped corners.
	for position: Vector2 in [world_rect.position + Vector2(32, 48), world_rect.end - Vector2(32, 48)]:
		player.global_position = position
		await _frames(75)
		var half_view: Vector2 = camera.get_viewport_rect().size / camera.zoom * 0.5
		var center: Vector2 = camera.get_screen_center_position()
		assert(center.x - half_view.x >= world_rect.position.x - 1)
		assert(center.y - half_view.y >= world_rect.position.y - 1)
		assert(center.x + half_view.x <= world_rect.end.x + 1)
		assert(center.y + half_view.y <= world_rect.end.y + 1)
	print("PASS: actual camera 80%%/45%%, accepted intent debounce/reversal, passive drift, physics fall %.3fpx/s (max %.4f), resize/zoom and four bounds" % [fall_speed, maximum_ratio])
	scene.queue_free()
	quit()

func _accept_input(action: String) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if not action.is_empty():
		Input.action_press(action)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await physics_frame
	await process_frame
	player.set_physics_process(false)
	Input.action_release("move_left")
	Input.action_release("move_right")

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame
	camera.force_update_scroll()

func _ratio() -> Vector2:
	camera.force_update_scroll()
	return (player.get_viewport().get_canvas_transform() * player.global_position) / camera.get_viewport_rect().size

func _assert_ratio(expected: Vector2) -> void:
	var actual: Vector2 = _ratio()
	assert(absf(actual.x - expected.x) < 0.015 and absf(actual.y - expected.y) < 0.015,
		"Expected screen ratio %s, got %s" % [expected, actual])
