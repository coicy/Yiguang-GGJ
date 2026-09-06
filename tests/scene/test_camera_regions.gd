extends SceneTree
## Camera fixtures instantiate production scenes only. Frozen positions/path drivers
## below test framing, not gameplay reachability through the authored obstacles.

const MAIN_PATH := "res://scenes/levels/Level_main.tscn"
const AUTHORITATIVE_PATH := "res://scenes/levels/level_01.tscn"
const LEGACY_PATH := "res://scenes/level_01.tscn"
const LOWER_SURFACE: float = 475.5
const UPPER_SURFACE: float = 3.5
# The inner wall face is 1336.5. The authored camera permits its opaque thickness
# through x=1370, while excluding the space outside the wall.
const RIGHT_WALL: float = 1370.0
const EPSILON: float = 0.06

var _player: Player
var _camera: Camera2D
var _framing: Node
# Runtime scene loading also defers HandbuiltLevel's Autoload-dependent script
# compilation until SceneTree has registered the production singletons.
var _level: Node2D
var _sampler: ViewSampler
var _checks: int = 0
var _failures: PackedStringArray = []

class ViewSampler extends Node:

	signal sampled

	var camera: Camera2D
	var view := Rect2()
	var center := Vector2.ZERO

	func _physics_process(_delta: float) -> void:
		camera.force_update_scroll()
		var size: Vector2 = camera.get_viewport_rect().size / camera.zoom
		center = camera.get_screen_center_position()
		view = Rect2(center - size * 0.5, size)
		sampled.emit()


class PathDriver extends Node:
	## A deterministic camera-only trajectory, advanced before framing at physics Hz.
	var target: Player
	var motion := Vector2.ZERO
	var ticks: int = 0
	var limit: int = 0
	var elapsed: float = 0.0

	func _physics_process(delta: float) -> void:
		if ticks >= limit:
			return
		target.velocity = motion
		target.global_position += motion * delta
		elapsed += delta
		ticks += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(55.0).timeout.connect(func() -> void: push_error("Camera region regression timeout"); quit(1))
	if FileAccess.file_exists(LEGACY_PATH):
		_expect(_scene_uid(AUTHORITATIVE_PATH) != _scene_uid(LEGACY_PATH),
			"The authoritative and legacy Level01 scenes have distinct identities")
	# Load the real app entry without changing ResourceUID mappings in this process.
	var app := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	var app_level := app.get_node_or_null("LevelHost/LevelMain/Level01") as Node2D
	_expect(app_level != null and app_level.scene_file_path == AUTHORITATIVE_PATH,
		"Default entry loads the authoritative Level01 scene path")
	_expect(app_level != null and app_level.get_node_or_null("%ForwardCameraFraming") != null,
		"Default entry actually includes the new framing controller")
	app.queue_free()
	paused = false
	await process_frame
	var scene := (load(MAIN_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	_level = scene.get_node("Level01") as Node2D
	_expect(_level.scene_file_path == AUTHORITATIVE_PATH, "Level_main F6 loads authoritative Level01")
	_player = _level.get_node("%Player") as Player
	_camera = _level.get_node("%Camera2D") as Camera2D
	_framing = _level.get_node_or_null("%ForwardCameraFraming")
	if _framing == null:
		_finish()
		return
	_sampler = ViewSampler.new()
	_sampler.camera = _camera
	_sampler.process_physics_priority = 500
	root.add_child(_sampler)
	_expect(_player.form_controller.switch_to(&"humanoid"), "Camera regression uses the real humanoid collision")
	# Allow the newly instantiated host to finish camera registration after the
	# separate default-entry inspection. Respawn checks below never wait this out.
	await _ticks(20)
	await _checkpoint_respawn()
	await _main_floor_jumps()
	await _low_passage_arrival_histories()
	await _actual_floating_platform_landing()
	await _blocked_gap_cube()
	await _right_connection()
	await _right_floor_jump()
	await _left_view_near_connection()
	await _actual_open_edge_descent()
	await _fall_stress()
	await _high_anchor_safety()
	Input.action_release("move_left")
	Input.action_release("move_right")
	scene.queue_free()
	_sampler.queue_free()
	await process_frame
	_finish()


func _checkpoint_respawn() -> void:
	# Invoke the production lifecycle callbacks, then let production gravity land.
	_level.call("_on_checkpoint_reached", _player, Vector2(329.0, 438.0))
	await _freeze(Vector2(1400.0, -900.0))
	_player.set_physics_process(true)
	_level.call("_on_actor_killed", _player)
	await _ticks(1)
	print("REGION CHECKPOINT FIRST: player %s, view %s, body %s" % [_player.global_position, _sampler.view, _player.get_camera_body_rect()])
	_expect(_sampler.view.end.y <= LOWER_SURFACE + EPSILON,
		"Checkpoint first visible frame does not reveal the lower floor underside")
	_expect(_body_visible(), "Checkpoint first visible frame includes the full player body")
	var previous: Vector2 = _sampler.center
	var maximum_step: float = 0.0
	var maximum_bottom: float = _sampler.view.end.y
	for tick: int in range(60):
		await _ticks(1)
		if _sampler.center.distance_to(previous) >= 2.0:
			print("REGION CHECKPOINT STEP: tick %d, player %s, center %s -> %s" % [tick, _player.global_position, previous, _sampler.center])
		maximum_step = maxf(maximum_step, _sampler.center.distance_to(previous))
		maximum_bottom = maxf(maximum_bottom, _sampler.view.end.y)
		previous = _sampler.center
	_expect(_player.is_on_floor(), "Checkpoint respawn actually falls and lands using production physics")
	_expect(maximum_bottom <= LOWER_SURFACE + EPSILON, "Every checkpoint landing frame respects the floor")
	_expect(maximum_step < 2.0, "Checkpoint landing does not cause a late camera correction")
	print("REGION CHECKPOINT: maximum bottom %.6f, maximum step %.6f" % [maximum_bottom, maximum_step])


func _low_passage_arrival_histories() -> void:
	# The 28px humanoid fits below Ground12 (underside -43) and above Floor2.
	# Its former feet position -76.51 overlapped Ground11 with the head.
	var destination := Vector2(40.0, -8.0)
	var views: Array[Rect2] = []
	for origin: Vector2 in [Vector2(329, 438), Vector2(-100, -7), Vector2(-130, -127)]:
		await _freeze(origin)
		# Camera-only arrival fixture: no claim that this straight path is playable.
		_player.global_position = destination
		_player.reset_physics_interpolation()
		await _ticks(1)
		_expect(_body_clear_of_world(), "Low-passage airborne fixture fits within the real authored free space")
		_expect(_sampler.view.end.y <= UPPER_SURFACE + EPSILON,
			"Airborne arrival obtains the upper-floor constraint before any supporting collision")
		await _ticks(90)
		views.append(_sampler.view)
		_expect(_sampler.view.end.y <= UPPER_SURFACE + EPSILON,
			"Upper low passage inherits Floor2 from airborne arrival at %s" % origin)
		_expect(_body_visible(), "Upper low-passage framing includes the player body")
	for view: Rect2 in views:
		_expect(view.position.distance_to(views[0].position) < 0.1,
			"Identical low-passage airborne position has history-independent settled composition")
	print("REGION LOW PASSAGE: history-independent views ", views)


func _actual_floating_platform_landing() -> void:
	var floating := _level.get_node("Level02/Geometry/Terrain/UpperTerrain/Ground11") as TerrainPiece
	var main_floor := _level.get_node("Level02/Geometry/Terrain/UpperTerrain/Ground13") as TerrainPiece
	await _freeze(Vector2(-130, -125))
	_player.set_physics_process(true)
	await _ticks(35)
	var supported: bool = false
	for index: int in range(_player.get_slide_collision_count()):
		supported = supported or _player.get_slide_collision(index).get_collider() == floating
	_expect(_player.is_on_floor() and supported, "Production gravity actually lands the player on Ground11")
	_expect(not floating.camera_main_floor, "Ground11 is a floating platform, not an added main floor")
	var region: Node = _framing.get_active_region()
	_expect(region != null and region.region_id == &"upper_room", "Actual Ground11 landing belongs to the upper room")
	_expect(_framing.get_active_main_floor() == main_floor, "Actual Ground11 landing inherits Ground13 as its main-floor boundary")
	_expect(_sampler.view.end.y <= UPPER_SURFACE + EPSILON, "Actual floating-platform landing respects the Floor2 surface")
	_expect(_body_visible(), "Actual floating-platform landing keeps the whole body visible")
	print("REGION ACTUAL FLOATING LANDING: player %s, view %s" % [_player.global_position, _sampler.view])


func _main_floor_jumps() -> void:
	for surface: float in [LOWER_SURFACE, UPPER_SURFACE]:
		await _freeze(Vector2(900, surface - 8.0))
		_player.set_physics_process(true)
		await _ticks(25)
		_expect(_player.is_on_floor(), "Region jump fixture physically lands at surface %.1f" % surface)
		Input.action_press("jump")
		await _ticks(2)
		Input.action_release("jump")
		var left_ground: bool = not _player.is_on_floor()
		var maximum_bottom: float = -INF
		var visible: bool = true
		for tick: int in range(45):
			await _ticks(1)
			left_ground = left_ground or not _player.is_on_floor()
			maximum_bottom = maxf(maximum_bottom, _sampler.view.end.y)
			visible = visible and _body_visible()
		_expect(left_ground, "Region jump actually leaves its main floor")
		_expect(maximum_bottom <= surface + EPSILON, "Every region jump frame retains its main-floor limit")
		_expect(visible, "Every region jump frame keeps the full body visible")
		print("REGION MAIN FLOOR JUMP: surface %.1f, maximum bottom %.6f" % [surface, maximum_bottom])


func _blocked_gap_cube() -> void:
	var cube := _level.find_child("Cube_de356dc0", true, false) as MoveableCube
	_expect(cube != null, "Production Floor2 gap still contains its authored moving cube")
	if cube == null:
		return
	# Existing hazards prevent using this fixture as a playable route onto the
	# cube. Keep the player in the legal low-passage airborne camera fixture and query
	# the actual World collider across the gap before/after real cube movement.
	await _freeze(Vector2(40, -8))
	_expect(_gap_blocker() == cube, "The real World collider blocks descent through the original gap")
	_expect(_sampler.view.end.y <= UPPER_SURFACE + EPSILON,
		"The low-passage fixture retains the upper-room floor constraint while the gap is blocked")
	_expect(cube.activate(), "Gap regression uses the production cube activation")
	var maximum_bottom: float = -INF
	for tick: int in range(80):
		await _ticks(1)
		maximum_bottom = maxf(maximum_bottom, _sampler.view.end.y)
	_expect(not cube.is_moving() and absf(cube.global_position.y + 3.0) < 0.1,
		"Original cube motion ends at its real destination in the Floor2 gap")
	_expect(_gap_blocker() == cube, "The lowered cube still physically blocks the Floor2 opening")
	_expect(maximum_bottom <= UPPER_SURFACE + EPSILON,
		"The camera does not mistake cube activation for an open floor connection")
	print("REGION BLOCKED GAP: maximum bottom %.6f, cube destination %s" % [maximum_bottom, cube.global_position])


func _right_connection() -> void:
	await _freeze(Vector2(1170, 160))
	_expect(_sampler.view.end.x <= RIGHT_WALL + EPSILON, "Right connection does not display behind its inner wall")
	_expect(_body_visible(), "Narrow right connection preserves the full player body")
	# Kinematic camera fixture tests continuous region changes independently from
	# vine input/path collision. The production player is intentionally frozen.
	var ascent: Dictionary = await _drive_fixture(Vector2(0, -300), 70)
	_expect(float(ascent.maximum_step) < 24.0, "Right-connector ascent has no room-switch camera cut")
	_expect(bool(ascent.body_visible), "Right-connector ascent keeps the body visible every physics tick")
	_expect(float(ascent.maximum_right_beside_wall) <= RIGHT_WALL + EPSILON,
		"Right-connector ascent respects the wall while the player is beside it")
	print("REGION RIGHT ASCENT: ", ascent)
	var descent: Dictionary = await _drive_fixture(Vector2(0, 300), 70)
	_expect(float(descent.maximum_step) < 24.0, "Right-connector descent has no room-switch camera cut")
	_expect(bool(descent.body_visible), "Right-connector descent keeps the body visible every physics tick")
	_expect(float(descent.maximum_right_beside_wall) <= RIGHT_WALL + EPSILON,
		"Right-connector descent respects the wall while the player is beside it")
	print("REGION RIGHT DESCENT: ", descent)


func _actual_open_edge_descent() -> void:
	# Start just above the real open west end of Ground13, then use real movement.
	await _freeze(Vector2(-245, -5))
	_player.set_physics_process(true)
	await _ticks(25)
	_expect(_player.is_on_floor(), "Open-edge fixture actually lands on Ground13")
	var initial_position: Vector2 = _player.global_position
	var previous: Vector2 = _sampler.center
	var maximum_step: float = 0.0
	var visible: bool = true
	var crossed: bool = false
	var supported_floor_hidden: bool = true
	Input.action_press("move_left")
	for tick: int in range(40):
		await _ticks(1)
		if _player.global_position.x < -290.0:
			Input.action_release("move_left")
		maximum_step = maxf(maximum_step, _sampler.center.distance_to(previous))
		previous = _sampler.center
		visible = visible and _body_visible()
		if _player.is_on_floor() and _player.get_camera_body_rect().end.y <= UPPER_SURFACE + EPSILON:
			supported_floor_hidden = supported_floor_hidden and _sampler.view.end.y <= UPPER_SURFACE + EPSILON
		crossed = crossed or (_player.global_position.x < -280.0 and _player.global_position.y > 20.0)
	Input.action_release("move_left")
	_expect(crossed, "Real accepted input and gravity carry the player beyond Floor2 and below its surface")
	_expect(visible, "Every real open-edge descent frame includes the body")
	_expect(supported_floor_hidden, "A body still physically supported at the main-floor lip keeps its floor hidden")
	_expect(maximum_step < 24.0, "Real open-edge descent avoids a region-switch camera cut")
	_expect(_sampler.view.end.y > UPPER_SURFACE + 20.0, "Camera follows the real descent into the lower space")
	print("REGION REAL EDGE: start %s, end %s, maximum step %.6f" % [initial_position, _player.global_position, maximum_step])


func _right_floor_jump() -> void:
	# Real movement crosses the old premature outside-room threshold at feet435.
	await _freeze(Vector2(1300, LOWER_SURFACE - 8.0))
	_player.set_physics_process(true)
	await _ticks(25)
	_expect(_player.is_on_floor(), "Right-floor jump actually lands inside the wall at x1300")
	var previous: Vector2 = _sampler.center
	var maximum_step: float = 0.0
	var crossed: bool = false
	var visible: bool = true
	Input.action_press("jump")
	for tick: int in range(60):
		await _ticks(1)
		if tick == 12:
			Input.action_release("jump")
		crossed = crossed or _player.get_camera_body_rect().end.y < 435.0
		maximum_step = maxf(maximum_step, _sampler.center.distance_to(previous))
		previous = _sampler.center
		visible = visible and _body_visible()
	Input.action_release("jump")
	_expect(crossed, "Real right-floor jump crosses feet435 while remaining inside the wall")
	_expect(maximum_step < 24.0, "Right-floor jump does not switch to the outside room and cut sideways")
	_expect(visible, "Right-floor jump keeps the entire body visible")
	print("REGION RIGHT FLOOR JUMP: maximum step %.6f" % maximum_step)


func _left_view_near_connection() -> void:
	await _freeze(Vector2(1100, -100), -1.0)
	await _ticks(90)
	var resting_ratio: float = (_player.global_position.x - _sampler.view.position.x) / _sampler.view.size.x
	_expect(absf(resting_ratio - 0.8) < 0.015,
		"Stationary left-facing upper-room player is not attracted to the right connector")
	# Camera-only leftward path: no claim of a playable straight route through
	# the upper mechanism geometry. Direction and motion remain independent.
	var driver := PathDriver.new()
	driver.target = _player
	driver.motion = Vector2(-120, 0)
	driver.limit = 40
	driver.process_physics_priority = 100
	root.add_child(driver)
	var minimum_ratio: float = INF
	var maximum_ratio: float = -INF
	while driver.ticks < driver.limit:
		await _ticks(1)
		var ratio: float = (_player.global_position.x - _sampler.view.position.x) / _sampler.view.size.x
		minimum_ratio = minf(minimum_ratio, ratio)
		maximum_ratio = maxf(maximum_ratio, ratio)
	driver.queue_free()
	_player.velocity = Vector2.ZERO
	_expect(minimum_ratio > 0.785 and maximum_ratio < 0.815,
		"Every leftward camera-fixture tick preserves the available 80 percent forward view")
	print("REGION LEFT VIEW: resting %.6f, moving %.6f..%.6f" % [resting_ratio, minimum_ratio, maximum_ratio])


func _fall_stress() -> void:
	await _freeze(Vector2(242, 55))
	# The cube blocks the authored gap above. This fixture starts BELOW it and
	# samples 900 px/s physics-time motion; it is not evidence the cube opened.
	var start_y: float = _player.global_position.y
	var falling: Dictionary = await _drive_fixture(Vector2(0, 900), 13)
	var speed: float = (_player.global_position.y - start_y) / float(falling.elapsed)
	_expect(absf(speed - 900.0) < 0.01, "Fall stress advances at 900 px/s independent of rendering FPS")
	_expect(bool(falling.body_visible), "900 px/s fall keeps the player body visible at every physics tick")
	_expect(float(falling.maximum_step) < 24.0, "900 px/s fall follows continuously")
	print("REGION FALL: speed %.3f px/s, %s" % [speed, falling])


func _high_anchor_safety() -> void:
	# Camera-only safety fixture at the enabled high anchor. It does not prove
	# that a player can reach the anchor using the current authored route.
	await _freeze(Vector2(358, -1716))
	_expect(_body_visible(), "An in-world high-anchor fixture is not lost above the historical camera top")


func _drive_fixture(motion: Vector2, ticks: int) -> Dictionary:
	var driver := PathDriver.new()
	driver.target = _player
	driver.motion = motion
	driver.limit = ticks
	driver.process_physics_priority = 100
	root.add_child(driver)
	var previous: Vector2 = _sampler.center
	var maximum_step: float = 0.0
	var maximum_right: float = -INF
	var maximum_right_beside_wall: float = -INF
	var visible: bool = true
	while driver.ticks < ticks:
		await _ticks(1)
		if _sampler.center.distance_to(previous) >= 24.0:
			print("REGION PATH STEP: tick %d, player %s, center %s -> %s" % [driver.ticks, _player.global_position, previous, _sampler.center])
		maximum_step = maxf(maximum_step, _sampler.center.distance_to(previous))
		maximum_right = maxf(maximum_right, _sampler.view.end.x)
		if _player.global_position.x >= 1124.0 and _player.global_position.y >= 10.0 \
				and _player.global_position.y <= 435.0:
			maximum_right_beside_wall = maxf(maximum_right_beside_wall, _sampler.view.end.x)
			if _sampler.view.end.x > RIGHT_WALL + EPSILON:
				print("REGION WALL OVERSHOOT: player %s, right %.6f" % [_player.global_position, _sampler.view.end.x])
		previous = _sampler.center
		visible = visible and _body_visible()
	var result: Dictionary = {"maximum_step": maximum_step, "maximum_right": maximum_right,
		"maximum_right_beside_wall": maximum_right_beside_wall,
		"body_visible": visible, "elapsed": driver.elapsed, "ticks": driver.ticks}
	driver.queue_free()
	_player.velocity = Vector2.ZERO
	return result


func _freeze(position: Vector2, direction: float = 1.0) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	_player.cancel_actions()
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO
	_player.global_position = position
	_player.reset_physics_interpolation()
	_framing.reset_for_respawn(direction)
	await _ticks(2)


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await _sampler.sampled


func _body_visible() -> bool:
	var body: Rect2 = _player.get_camera_body_rect()
	return _sampler.view.grow(EPSILON).encloses(body)


func _body_clear_of_world() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _player.collision_shape.shape
	query.transform = _player.collision_shape.global_transform
	query.collision_mask = 1
	query.exclude = [_player.get_rid()]
	return _player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _gap_blocker() -> CollisionObject2D:
	var query := PhysicsRayQueryParameters2D.create(Vector2(242, -50), Vector2(242, 43), 1)
	var hit: Dictionary = _player.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as CollisionObject2D


func _scene_uid(path: String) -> String:
	var first_line: String = FileAccess.get_file_as_string(path).get_slice("\n", 0)
	var expression := RegEx.new()
	expression.compile("uid=\"([^\"]+)\"")
	var match_result: RegExMatch = expression.search(first_line)
	return match_result.get_string(1) if match_result != null else ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CAMERA REGIONS: %d checks, %d failures, max render FPS %d, physics %d Hz" % [_checks, _failures.size(), Engine.max_fps, Engine.physics_ticks_per_second])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
