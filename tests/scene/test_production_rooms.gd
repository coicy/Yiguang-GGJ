extends SceneTree
## Production geometry acceptance, driven by registration.json.
## Usage: godot --path <project> --script res://tests/scene/test_production_rooms.gd -- room=workshop
## Add --capture with a real rendering driver to save the reached endpoint.
## A/D/Space are physical key events. Only initialization writes player position,
## velocity and form. Encounters are explicitly completed/opened for isolation:
## this is neither combat acceptance nor an independent human full playthrough.
## A jump waypoint means one jump from the preceding reached point. Add a walking
## waypoint at a run-up lip when necessary; a same-direction walk-to-jump handoff
## retains normal horizontal momentum. No generated test map is used.

const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
const HEIGHT_TOLERANCE: float = 3.0
const HORIZONTAL_TOLERANCE: float = 8.0
const STUCK_SECONDS: float = 1.5
const POLYGON_TOLERANCE: float = 0.25
const KEY_ACTIONS: Dictionary[Key, StringName] = {
	KEY_A: &"move_left", KEY_D: &"move_right", KEY_SPACE: &"jump"
}

var _room_id: String = ""
var _capture_requested: bool = false
var _registration: Dictionary = {}
var _route: Dictionary = {}
var _waypoints: Array[Dictionary] = []
var _bounds: Rect2
var _start: Vector2
var _form_id: StringName
var _main: Node
var _level: GreenhouseLevel
var _player: Player
var _room: Node2D
var _keys: Dictionary[Key, bool] = {}
var _checks: int = 0
var _failures: PackedStringArray = []
var _jump_count: int = 0
var _expected_jumps: int = 0
var _previous_position: Vector2
var _max_frame_step: float = 0.0
var _frame_step_limit: float = 0.0
var _monitor_motion: bool = false
var _isolated_encounters: int = 0


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("room="):
			_room_id = argument.trim_prefix("room=")
		elif argument.begins_with("--room="):
			_room_id = argument.trim_prefix("--room=")
		elif argument == "--capture":
			_capture_requested = true
	call_deferred("_run")


func _run() -> void:
	if not _load_registration():
		await _finish()
		return
	if _capture_requested and DisplayServer.get_name() == "headless":
		_expect(false, "--capture requires a real rendering driver; do not combine it with --headless")
		await _finish()
		return

	_main = MAIN.instantiate()
	root.add_child(_main)
	# Child Host registers after its first idle frame. Do not simulate the route
	# until the production level and its single camera owner have initialized.
	await process_frame
	_level = _main.get_node_or_null("LevelHost/LevelMain/Level01") as GreenhouseLevel
	if not _expect(_level != null, "F5 entry resolves the production GreenhouseLevel"):
		await _finish()
		return
	_player = _level.get_node_or_null("Actors/Player") as Player
	if not _expect(_player != null, "Production player is present"):
		await _finish()
		return
	if not _verify_registered_room():
		await _finish()
		return

	# Isolation is done before the start placement. No enemy damage is simulated.
	for encounter: EncounterController in _level.encounters:
		encounter.completed = true
		encounter.reset_encounter()
		_isolated_encounters += 1
	_level.current_encounter = null
	_level._encounter_camera.priority = 0
	_level.combat_hud.set_boss(null)

	_release_keys()
	_player.cancel_actions()
	_player.form_controller.restore_form(_form_id)
	_player.global_position = _start
	_player.velocity = Vector2.ZERO
	_player.movement.jumped.connect(_on_jumped)
	_level._reset_exploration_camera()
	_previous_position = _player.global_position
	var form := _player.form_controller.get_current()
	_frame_step_limit = (
		Vector2(form.move_speed, maxf(form.max_fall_speed, absf(form.jump_force))).length()
		/ float(Engine.physics_ticks_per_second) + 2.0
	)
	_monitor_motion = true

	if not await _settle_at_start():
		await _finish()
		return
	print("PRODUCTION ROOM terrain-only room=%s form=%s start=%s isolated_encounters=%d" % [
		_room_id, _form_id, _player.global_position, _isolated_encounters
	])
	for index in range(_waypoints.size()):
		var waypoint := _waypoints[index]
		var next_waypoint: Dictionary = _waypoints[index + 1] if index + 1 < _waypoints.size() else {}
		if not await _reach_waypoint(index, waypoint, next_waypoint):
			break

	_release_keys()
	if _failures.is_empty():
		_expect(_jump_count == _expected_jumps, "Exactly one actual jump per jump waypoint; no buffered repeat jumps")
		_expect(not _level.dead and _level.death_count == 0, "Terrain route finishes without death or retry")
		_expect(_player.current_form_id() == _form_id, "Route preserves its initialized form")
		_expect(_max_frame_step <= _frame_step_limit, "Every sampled displacement remains continuous physics")
		if _capture_requested:
			await _capture_endpoint()
	await _finish()


func _load_registration() -> bool:
	if not _expect(not _room_id.is_empty(), "Supply room=<id> after the command-line -- separator"):
		return false
	for character: String in _room_id:
		if not _expect(character in "abcdefghijklmnopqrstuvwxyz0123456789_-", "Room id contains only lowercase identifier characters"):
			return false
	var path := "res://assets/source/rooms/%s/registration.json" % _room_id
	if not _expect(FileAccess.file_exists(path), "Selected room has registration.json: " + path):
		return false
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if not _expect(error == OK, "Registration parses: %s line %d" % [parser.get_error_message(), parser.get_error_line()]):
		return false
	if not _expect(parser.data is Dictionary, "Registration root is an object"):
		return false
	_registration = parser.data
	if not _expect(_valid_number_array(_registration.get("bounds"), 4), "Registration bounds is [world_x, world_y, width, height]"):
		return false
	var bounds_values: Array = _registration["bounds"]
	_bounds = Rect2(float(bounds_values[0]), float(bounds_values[1]), float(bounds_values[2]), float(bounds_values[3]))
	if not _expect(_bounds.size.x > 0.0 and _bounds.size.y > 0.0, "Room bounds has positive size"):
		return false
	if not _expect(_registration.get("test_route") is Dictionary, "Selected room provides test_route"):
		return false
	_route = _registration["test_route"]
	if not _expect(_valid_number_array(_route.get("start"), 2), "Route start is a finite world foot point"):
		return false
	_start = _vector(_route["start"])
	_form_id = StringName(str(_route.get("form", "")))
	if not _expect(_form_id in [&"humanoid", &"mature"], "Terrain route selects humanoid or mature"):
		return false
	if not _expect(_inside_bounds(_start), "Start belongs to the registered room bounds"):
		return false
	if not _expect(_route.get("waypoints") is Array, "Route waypoints is an array"):
		return false
	var entries: Array = _route["waypoints"]
	if not _expect(not entries.is_empty(), "At least one real movement waypoint is required"):
		return false
	for index in range(entries.size()):
		if not _expect(entries[index] is Dictionary, "Waypoint %d is an object" % index):
			return false
		var waypoint: Dictionary = entries[index]
		if not _expect(_is_number(waypoint.get("x")) and _is_number(waypoint.get("y")) and waypoint.get("jump") is bool, "Waypoint %d supplies finite x/y and boolean jump" % index):
			return false
		var target := Vector2(float(waypoint["x"]), float(waypoint["y"]))
		if not _expect(_inside_bounds(target), "Waypoint %d belongs to the registered bounds" % index):
			return false
		_waypoints.append(waypoint)
		if bool(waypoint["jump"]):
			_expected_jumps += 1
	return true


func _verify_registered_room() -> bool:
	var scene_path := str(_registration.get("scene_node", "Rooms/" + _room_id.to_pascal_case()))
	if not _expect(scene_path.begins_with("Rooms/") and not scene_path.contains(".."), "Room is under the production Rooms branch"):
		return false
	_room = _level.get_node_or_null(NodePath(scene_path)) as Node2D
	if not _expect(_room != null, "Registered room node exists: " + scene_path):
		return false
	_expect(_room.global_position.is_equal_approx(Vector2.ZERO), "Room node keeps the registered world-coordinate origin")

	if _registration.has("foreground_node"):
		var foreground := _room.get_node_or_null(NodePath(str(_registration["foreground_node"]))) as Sprite2D
		if _expect(foreground != null, "Registered foreground Sprite2D exists"):
			if _registration.has("foreground_origin"):
				if _expect(_valid_number_array(_registration["foreground_origin"], 2), "Foreground origin is a finite point"):
					_expect(foreground.global_position.distance_to(_vector(_registration["foreground_origin"])) <= POLYGON_TOLERANCE, "Foreground world origin matches registration")
			if _registration.has("foreground_scale"):
				if _expect(_is_number(_registration["foreground_scale"]), "Foreground scale is finite"):
					var scale_value := float(_registration["foreground_scale"])
					_expect(scale_value > 0.0 and foreground.global_scale.is_equal_approx(Vector2.ONE * scale_value), "Foreground uses the registered uniform scale")
			_expect(foreground.texture != null, "Registered foreground has a loaded texture")

	if _registration.has("solids"):
		if not _expect(_registration["solids"] is Array, "Registered solids is an array"):
			return false
		for entry: Variant in _registration["solids"]:
			if not _expect(entry is Dictionary, "Registered solid is an object"):
				return false
			var solid: Dictionary = entry
			if not _expect(solid.get("name") is String and solid.get("polygon") is Array, "Solid has a name and world polygon"):
				return false
			var expected: PackedVector2Array = []
			for point: Variant in solid["polygon"]:
				if not _expect(_valid_number_array(point, 2), "Solid %s has finite polygon points" % solid["name"]):
					return false
				expected.append(_vector(point))
			if not _expect(expected.size() >= 3, "Solid %s is a polygon" % solid["name"]):
				return false
			var body := _room.get_node_or_null(NodePath(str(solid["name"])))
			if body == null:
				body = _room.find_child(str(solid["name"]), true, false)
			if not _expect(body != null, "Registered solid exists: " + str(solid["name"])):
				continue
			var candidates: Array[Node] = [body] if body is CollisionPolygon2D else body.find_children("*", "CollisionPolygon2D", true, false)
			var matched := false
			for candidate: Node in candidates:
				var collision := candidate as CollisionPolygon2D
				var collision_owner := collision.get_parent() as CollisionObject2D
				if collision.disabled or collision_owner == null or (collision_owner.collision_layer & 1) == 0:
					continue
				var actual: PackedVector2Array = []
				for point: Vector2 in collision.polygon:
					actual.append(collision.to_global(point))
				if _polygons_match(expected, actual):
					matched = true
					break
			_expect(matched, "Solid %s active World collision matches registered world vertices" % solid["name"])
	return _failures.is_empty()


func _settle_at_start() -> bool:
	for tick in range(30):
		if not await _physics_tick():
			return false
		if _player.is_on_floor():
			break
	return _expect(
		_player.is_on_floor()
		and absf(_player.global_position.y - _start.y) <= HEIGHT_TOLERANCE
		and absf(_player.global_position.x - _start.x) <= HORIZONTAL_TOLERANCE,
		"Start settles on its registered surface, actual %s expected %s" % [_player.global_position, _start]
	)


func _reach_waypoint(index: int, waypoint: Dictionary, next_waypoint: Dictionary) -> bool:
	var target := Vector2(float(waypoint["x"]), float(waypoint["y"]))
	var requires_jump := bool(waypoint["jump"])
	var jumps_before := _jump_count
	var airborne_seen := false
	var first_landing_seen := false
	var still_ticks := 0
	var stagnant_origin := _player.global_position
	var speed := maxf(_player.form_controller.get_current().move_speed, 1.0)
	var budget := ceili((4.0 + _player.global_position.distance_to(target) / speed * 3.0) * Engine.physics_ticks_per_second)
	budget = mini(budget, Engine.physics_ticks_per_second * 30)
	if requires_jump and not _expect(_player.is_on_floor(), "Jump waypoint %d starts grounded" % index):
		return false
	_key(KEY_SPACE, false)
	if requires_jump:
		_set_direction(signf(target.x - _player.global_position.x))
		_key(KEY_SPACE, true)

	for tick in range(budget):
		if requires_jump:
			airborne_seen = airborne_seen or not _player.is_on_floor()
			if airborne_seen and _player.is_on_floor():
				first_landing_seen = true
				_key(KEY_SPACE, false)
			elif not first_landing_seen:
				# A real window losing focus may clear Input while our key cache
				# still says held. Restore the requested key, never movement state.
				_key(KEY_SPACE, true)
			if not _expect_no_extra_jump(jumps_before, index):
				return false
		var dx := target.x - _player.global_position.x
		var at_surface := _player.is_on_floor() and absf(_player.global_position.y - target.y) <= HEIGHT_TOLERANCE
		var jump_complete := not requires_jump or (airborne_seen and first_landing_seen and _jump_count == jumps_before + 1)
		if at_surface and absf(dx) <= HORIZONTAL_TOLERANCE and jump_complete:
			_key(KEY_SPACE, false)
			_expect(true, "Waypoint %d reached via input" % index)
			print("ROOM WAYPOINT room=%s index=%d jump=%s expected=%s actual=%s y_error=%.3f" % [
				_room_id, index, requires_jump, target, _player.global_position, absf(_player.global_position.y - target.y)
			])
			# Keep momentum only for an authored same-direction walking run-up.
			var keep_runup := false
			if not requires_jump and not next_waypoint.is_empty() and bool(next_waypoint["jump"]):
				var next_direction := signf(float(next_waypoint["x"]) - target.x)
				keep_runup = not is_zero_approx(next_direction) and next_direction == signf(_player.velocity.x)
			if not keep_runup:
				_set_direction(0.0)
				for settle_tick in range(4):
					if not await _physics_tick():
						return false
				_expect(_player.is_on_floor() and absf(_player.global_position.y - target.y) <= HEIGHT_TOLERANCE, "Waypoint %d remains on its surface after input release" % index)
			return _failures.is_empty()

		_set_direction(signf(dx) if absf(dx) > 2.0 else 0.0)
		if not await _physics_tick():
			return false
		if _player.global_position.distance_to(stagnant_origin) > 1.0:
			still_ticks = 0
			stagnant_origin = _player.global_position
		else:
			still_ticks += 1
		if still_ticks >= ceili(STUCK_SECONDS * Engine.physics_ticks_per_second):
			return _expect(false, "Waypoint %d stuck at %s, expected %s; %s" % [index, _player.global_position, target, _collision_summary()])
		if requires_jump and not airborne_seen and tick > ceili(0.4 * Engine.physics_ticks_per_second):
			return _expect(false, "Waypoint %d Space did not produce an actual jump" % index)
	return _expect(false, "Waypoint %d timed out at %s, expected %s; %s" % [index, _player.global_position, target, _collision_summary()])


func _physics_tick() -> bool:
	await physics_frame
	if not is_instance_valid(_player):
		return _expect(false, "Production player disappeared during the route")
	if _level.dead or _player.combat.health.current <= 0 or _level.death_count != 0:
		return _expect(false, "Terrain route encountered death; no retry/teleport is allowed")
	if paused or _level.finished:
		return _expect(false, "Unexpected pause/completion interrupted the terrain route")
	if _player.current_form_id() != _form_id:
		return _expect(false, "Unexpected form change during the fixed-form terrain route")
	if not _inside_bounds(_player.global_position):
		return _expect(false, "Route left registered room bounds at %s (bounds %s)" % [_player.global_position, _bounds])
	if _monitor_motion:
		var displacement := _previous_position.distance_to(_player.global_position)
		_max_frame_step = maxf(_max_frame_step, displacement)
		_previous_position = _player.global_position
		if displacement > _frame_step_limit:
			return _expect(false, "Noncontinuous physics displacement %.3f exceeds %.3f" % [displacement, _frame_step_limit])
	return true


func _expect_no_extra_jump(before: int, index: int) -> bool:
	if _jump_count > before + 1:
		return _expect(false, "Waypoint %d produced an unintended repeated jump" % index)
	return true


func _on_jumped() -> void:
	_jump_count += 1


func _collision_summary() -> String:
	var names: PackedStringArray = []
	for index in range(_player.get_slide_collision_count()):
		var collider := _player.get_slide_collision(index).get_collider() as Node
		if collider != null:
			names.append(str(collider.get_path()))
	return "velocity=%s floor=%s contacts=%s" % [_player.velocity, _player.is_on_floor(), ", ".join(names)]


func _inside_bounds(point: Vector2) -> bool:
	# Footpoint tolerance also permits an endpoint exactly on a shared room port.
	return (
		point.x >= _bounds.position.x - HORIZONTAL_TOLERANCE
		and point.x <= _bounds.end.x + HORIZONTAL_TOLERANCE
		and point.y >= _bounds.position.y - HEIGHT_TOLERANCE
		and point.y <= _bounds.end.y + HEIGHT_TOLERANCE
	)


func _polygons_match(expected: PackedVector2Array, actual: PackedVector2Array) -> bool:
	if expected.size() != actual.size():
		return false
	for first in range(actual.size()):
		for direction: int in [1, -1]:
			var matches := true
			for index in range(expected.size()):
				var other := posmod(first + direction * index, actual.size())
				if expected[index].distance_to(actual[other]) > POLYGON_TOLERANCE:
					matches = false
					break
			if matches:
				return true
	return false


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _valid_number_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for element: Variant in value:
		if not _is_number(element):
			return false
	return true


func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _set_direction(direction: float) -> void:
	_key(KEY_A, direction < 0.0)
	_key(KEY_D, direction > 0.0)


func _key(code: Key, pressed: bool) -> void:
	if _keys.get(code, false) == pressed and (not pressed or Input.is_action_pressed(KEY_ACTIONS[code])):
		return
	_keys[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_keys() -> void:
	for code: Key in KEY_ACTIONS.keys():
		_key(code, false)
		Input.action_release(KEY_ACTIONS[code])


func _capture_endpoint() -> void:
	_set_direction(0.0)
	_key(KEY_SPACE, false)
	# Let the real Host complete any room transition. The player/camera are never
	# repositioned or disabled to compose this endpoint screenshot.
	for tick in range(30):
		if not await _physics_tick():
			return
	var endpoint := _waypoints.back()
	_expect(_player.is_on_floor() and absf(_player.global_position.y - float(endpoint["y"])) <= HEIGHT_TOLERANCE, "Capture still shows the reached real endpoint")
	if not _failures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var folder := "res://build/qa/production-rooms"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if not _expect(error == OK, "Endpoint capture directory is available"):
		return
	var image := root.get_texture().get_image()
	var path := "%s/%s-%s.png" % [folder, _room_id, _form_id]
	_expect(image.save_png(path) == OK, "Actual input endpoint image saved: " + path)


func _finish() -> void:
	_release_keys()
	paused = false
	_monitor_motion = false
	if is_instance_valid(_level):
		_level.feedback.clear()
		_level.sounds.stop_all()
	if is_instance_valid(_main):
		for node: Node in _main.find_children("*", "", true, false):
			if node is AudioStreamPlayer:
				(node as AudioStreamPlayer).stop()
			elif node is AudioStreamPlayer2D:
				(node as AudioStreamPlayer2D).stop()
			elif node is AudioStreamPlayer3D:
				(node as AudioStreamPlayer3D).stop()
		_main.queue_free()
		await process_frame
	print("PRODUCTION ROOM: room=%s assertions=%d failures=%d jumps=%d/%d max_step=%.3f; terrain isolation, not combat or human playthrough" % [
		_room_id, _checks, _failures.size(), _jump_count, _expected_jumps, _max_frame_step
	])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _expect(value: bool, message: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(message)
		print("ROOM FAILURE: " + message)
	return value
