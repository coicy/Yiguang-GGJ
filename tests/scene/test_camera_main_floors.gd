extends SceneTree

const LEVEL_SCENE_PATH: String = "res://scenes/levels/Level_main.tscn"
var player: Player
var camera: Camera2D
var framing: Node
var maximum_floor_overshoot: float = -INF

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(55.0).timeout.connect(func() -> void: push_error("Main floor regression timeout"); quit(1))
	var scene := (load(LEVEL_SCENE_PATH) as PackedScene).instantiate() as Node2D
	root.add_child(scene)
	await physics_frame
	var level := scene.get_node("Level01")
	player = level.get_node("%Player") as Player
	camera = player.get_node("Camera2D") as Camera2D
	framing = level.get_node("%ForwardCameraFraming")
	# Preserve coverage for reusable scenes without region data. The formal main
	# region lifecycle is exercised separately in test_camera_regions.
	framing.regions_enabled = false
	framing.reset_for_respawn(1.0)
	assert(player.form_controller.switch_to(&"humanoid"))
	var start := level.get_node("Geometry/Terrain/StartFloor") as TerrainPiece
	var left := level.get_node("Level02/Geometry/Terrain/UpperTerrain/Ground13") as TerrainPiece
	var right := level.get_node("Level02/Geometry/Terrain/UpperTerrain/Ground14") as TerrainPiece
	var reference := level.get_node("Geometry/Terrain/Floor2") as TerrainPiece
	assert(reference.get_camera_floor_rect().size == Vector2.ZERO)
	for floor_piece: TerrainPiece in [start, left, right]:
		assert(floor_piece.camera_main_floor)
		var expected: Rect2 = _collision_rect(floor_piece)
		assert(floor_piece.get_camera_floor_rect().is_equal_approx(expected))
		var stand_x: float = -200.0 if floor_piece == left else 900.0
		await _land_on(floor_piece, stand_x)
		assert(framing.get_active_main_floor() == floor_piece, "Standing must acquire %s" % floor_piece.name)
		await _frames(60)
		_assert_floor_bottom(expected.position.y)
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		var left_ground: bool = false
		for frame: int in range(45):
			await _frames(1)
			left_ground = left_ground or not player.is_on_floor()
			assert(framing.get_active_main_floor() == floor_piece, "Jump must retain the supporting main floor")
			_assert_floor_bottom(expected.position.y)
		assert(left_ground, "Jump test must actually leave the floor")
	# Stand on a higher, unmarked floating platform after acquiring Floor2.
	await _land_on(left, -100.0)
	var floating := level.get_node("Level02/Geometry/Terrain/UpperTerrain/Ground11") as TerrainPiece
	assert(not floating.camera_main_floor)
	await _land_on(floating, -100.0)
	assert(framing.get_active_main_floor() == left, "Floating platform must not replace main floor")
	# Exercise the exact floor-edge window on the open left end with real movement.
	await _land_on(left, -245.0)
	Input.action_press("move_left")
	var edge_released: bool = false
	for frame: int in range(30):
		await _frames(1)
		if player.global_position.x < -285.0:
			Input.action_release("move_left")
			player.velocity.x = 0.0
		if framing.get_active_main_floor() == null:
			edge_released = true
		var edge_ratio: Vector2 = _ratio()
		assert(edge_ratio.y > 0.0 and edge_ratio.y < 1.0, "Open-edge descent must remain visible")
	Input.action_release("move_left")
	assert(edge_released, "Leaving the real main-floor edge while descending must unlock the camera")
	# The production moving cube blocks walking into the opening from this side.
	# Place the falling fixture below that cube, then run real gravity in the gap.
	await _land_on(left, 175.0)
	player.global_position = Vector2(242.0, 45.0)
	player.velocity = Vector2(0.0, 120.0)
	# Freeze horizontal motion only while real gravity carries the body through the gap.
	var unlocked: bool = false
	for frame: int in range(30):
		player.velocity.x = 0.0
		await _frames(1)
		unlocked = unlocked or framing.get_active_main_floor() == null
		var ratio: Vector2 = _ratio()
		assert(ratio.y > 0.0 and ratio.y < 1.0, "Gap descent must keep player visible")
	assert(unlocked, "Falling through the main-floor gap must release its bottom limit")
	# Production death callback must reset the actual first camera image, no direct camera reset.
	player.set_physics_process(false)
	player.global_position = Vector2(1400, -900)
	await _frames(60)
	level.call("_on_actor_killed", player)
	await _frames(1)
	var respawn_ratio: Vector2 = _ratio()
	assert(absf(respawn_ratio.x - 0.2) < 0.015, "Respawn first frame must restore forward view: %s" % respawn_ratio)
	assert(respawn_ratio.y > 0.0 and respawn_ratio.y < 1.0, "Respawn first frame must show player")
	assert(framing.get_active_main_floor() == start, "Respawn must replace distant floor lock with spawn support")
	var view_height: float = camera.get_viewport_rect().size.y / camera.zoom.y
	var expected_spawn_y: float = 1.0 + (player.global_position.y - _collision_rect(start).position.y) / view_height
	assert(absf(respawn_ratio.y - expected_spawn_y) < 0.015, "Spawn floor bottom overrides the free-fall 45% ratio")
	print("PASS: actual main-level physics supports StartFloor/Ground13/Ground14, jump floor limits (max overshoot %.6f), floating platform, gap release and first-frame production respawn %s" % [maximum_floor_overshoot, respawn_ratio])
	scene.queue_free()
	quit()

func _collision_rect(piece: TerrainPiece) -> Rect2:
	# Expected bounds are obtained from the enabled authored collision, independently.
	var polygon := piece.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(not polygon.disabled and polygon.polygon.size() > 0)
	var expected := Rect2(polygon.to_global(polygon.polygon[0]), Vector2.ZERO)
	for point: Vector2 in polygon.polygon:
		expected = expected.expand(polygon.to_global(point))
	return expected

func _land_on(piece: TerrainPiece, x: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	player.cancel_actions()
	var shape: CollisionShape2D = player.collision_shape
	var bottom_offset: float = (shape.global_transform * shape.shape.get_rect()).end.y - player.global_position.y
	player.global_position = Vector2(x, _collision_rect(piece).position.y - bottom_offset - 8.0)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await _frames(25)
	assert(player.is_on_floor(), "Must actually land on %s" % piece.name)
	var supported: bool = false
	for index: int in player.get_slide_collision_count():
		supported = supported or player.get_slide_collision(index).get_collider() == piece
	assert(supported, "Expected physical support from %s" % piece.name)

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame
	camera.force_update_scroll()

func _assert_floor_bottom(surface: float) -> void:
	var bottom: float = camera.get_screen_center_position().y + camera.get_viewport_rect().size.y / camera.zoom.y * 0.5
	maximum_floor_overshoot = maxf(maximum_floor_overshoot, bottom - surface)
	assert(bottom <= surface + 0.05, "Screen bottom %.3f exceeds floor surface %.3f" % [bottom, surface])

func _ratio() -> Vector2:
	return (player.get_viewport().get_canvas_transform() * player.global_position) / camera.get_viewport_rect().size
