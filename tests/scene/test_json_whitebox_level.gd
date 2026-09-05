extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/json_whitebox_level.tscn")
const SOURCE_PATH := "res://data/Yiguang.json"
const GATED_RINGS := ["e33e56b0-96d0-11f1-9ec0-eb30919fa281", "e4d80980-96d0-11f1-9ec0-bf3ef0df67ce", "e638aaf0-96d0-11f1-9ec0-47d36b46fa53", "e6afd6c0-96d0-11f1-9ec0-230200d3b3cc"]
const DESTINATION_RINGS := ["e6481070-96d0-11f1-ba31-f968a2c6c8eb", "e6979000-96d0-11f1-ba31-7964dc9ae8c8", "e7204800-96d0-11f1-ba31-85359e1dc5d3", "e763e0b0-96d0-11f1-ba31-8b4b49d4e2c5"]
const B2 := "bbbb4660-96d0-11f1-9ec0-d3fb842dd849"
const C2 := "3005cb90-96d0-11f1-9ec0-231d9bef30a8"
const C6 := "322a3230-96d0-11f1-9ec0-65ba33f44fa8"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_SCENE.instantiate() as JsonWhiteboxLevel
	root.add_child(level)
	await physics_frame
	var source_data := _read_source_data()
	_assert_world_extents_and_camera(level, source_data)
	_assert_source_geometry_and_entities(level, source_data)
	for ring_id: String in GATED_RINGS:
		var ring := level.get_entity(ring_id) as VineAnchor
		assert(not ring.is_available() and not ring.is_in_group("vine_anchor") and not ring.visible)
	await _assert_button_to_cube_paths(level, source_data)
	for ring_id: String in GATED_RINGS:
		var ring := level.get_entity(ring_id) as VineAnchor
		assert(ring.is_available() and ring.is_in_group("vine_anchor") and ring.visible)
		var support := ring.get_parent() as MoveableCube
		assert(is_equal_approx(ring.global_position.y, support.get_world_rect().end.y + 8.0))
	_assert_supported_entity_binding(level)
	assert(level.get_data_issues().is_empty(), "The supplied map must not require hard-coded mechanism fallbacks.")
	level.queue_free()
	print("PASS: map references, B1/B2 motion, gated Rings and resizing attachments")
	# Let queued nodes and the audio mixer release stopped playback before shutdown.
	await process_frame
	await create_timer(0.1).timeout
	quit()


func _read_source_data() -> Dictionary:
	var parser := JSON.new()
	assert(parser.parse(FileAccess.get_file_as_string(SOURCE_PATH)) == OK)
	return parser.data as Dictionary


func _assert_world_extents_and_camera(level: JsonWhiteboxLevel, source_data: Dictionary) -> void:
	var expected_bounds := Rect2()
	var has_bounds := false
	var camera_rect := Rect2()
	for raw_level: Variant in source_data.get("levels", []):
		var source_level := raw_level as Dictionary
		var level_rect := Rect2(
			Vector2(float(source_level.get("worldX", 0)), float(source_level.get("worldY", 0))),
			Vector2(float(source_level.get("pxWid", 0)), float(source_level.get("pxHei", 0)))
		)
		expected_bounds = expected_bounds.merge(level_rect) if has_bounds else level_rect
		has_bounds = true
		for entity: Dictionary in _entities(source_level):
			if entity.get("__identifier", "") == "Camera":
				camera_rect = _world_rect(entity, source_level)
	var player := level.get_node("Player") as Player
	var camera := player.get_node("Camera") as Camera2D
	var expected_zoom := minf(1344.0 / camera_rect.size.x, 640.0 / camera_rect.size.y)
	assert(camera.zoom.is_equal_approx(Vector2.ONE * expected_zoom))
	assert(camera.position.is_zero_approx(), "Camera follow must be centred on the player; drag margins provide the look-ahead effect.")
	assert(camera.limit_left == int(expected_bounds.position.x))
	assert(camera.limit_top == int(expected_bounds.position.y))
	assert(camera.limit_right == int(expected_bounds.end.x))
	assert(camera.limit_bottom == int(expected_bounds.end.y))


func _assert_source_geometry_and_entities(level: JsonWhiteboxLevel, source_data: Dictionary) -> void:
	var source_entities := _entity_index(source_data)
	var destination_ids := _cube_destination_ids(source_entities)
	for entity_id: String in source_entities:
		var entity := source_entities[entity_id] as Dictionary
		var identifier := String(entity.get("__identifier", ""))
		if identifier in ["Start", "Camera"]:
			continue
		if destination_ids.has(entity_id) or entity_id in DESTINATION_RINGS:
			assert(level.get_entity(entity_id) == null, "Cube destination anchors must not create duplicate solid bodies.")
			continue
		var runtime_entity := level.get_entity(entity_id)
		assert(runtime_entity != null, "Missing source entity: %s" % identifier)
		var expected_rect := level.get_source_rect(entity_id)
		assert(expected_rect.is_equal_approx(_world_rect_from_index(entity, source_entities)), "Source world rectangle drifted for %s." % identifier)
		if runtime_entity is MoveableCube:
			assert((runtime_entity as MoveableCube).get_world_rect().is_equal_approx(expected_rect))
		elif runtime_entity is Node2D:
			var expected_position := expected_rect.get_center() if identifier in ["Ring", "DamageMachine"] else expected_rect.position
			assert((runtime_entity as Node2D).global_position.is_equal_approx(expected_position), "Runtime position mismatch: %s" % identifier)


func _assert_button_to_cube_paths(level: JsonWhiteboxLevel, source_data: Dictionary) -> void:
	var source_entities := _entity_index(source_data)
	for button_id: String in source_entities:
		var button_data := source_entities[button_id] as Dictionary
		if button_data.get("__identifier", "") != "Button":
			continue
		var button_targets := _linked_ids(button_data)
		assert(not button_targets.is_empty(), "Every supplied button must control a cube.")
		if button_id == "0f859c40-96d0-11f1-9ec0-a7f50fdb1f9d":
			assert(button_targets == ["14f1b660-96d0-11f1-ba31-2fb3210b8ae8"])
		if button_id == B2:
			assert(button_targets.size() == 2 and C2 in button_targets and C6 in button_targets)
		if button_id == "17ea7d40-96d0-11f1-9ec0-5b135eaa7d6d":
			assert(button_targets.size() == 2 and "3c92f320-96d0-11f1-9ec0-adb2f775b414" in button_targets and "dbcf3f60-96d0-11f1-ba31-81dc80293df2" in button_targets)
		var button := level.get_entity(button_id) as WhiteboxButton
		assert(button != null)
		assert(button.press(level.get_node("Player") as Player))
		for cube_id: String in button_targets:
			assert((level.get_entity(cube_id) as MoveableCube).is_moving(), "All linked cubes start together.")
		if button_id == B2:
			var a := level.get_entity(C2) as MoveableCube
			var b := level.get_entity(C6) as MoveableCube
			var distance := a.global_position.distance_to(b.global_position)
			for step: int in range(360):
				if not a.is_moving() and not b.is_moving():
					break
				await physics_frame
				assert(absf(a.global_position.distance_to(b.global_position) - distance) < 0.01, "Linked cubes must stay rigid throughout rotation.")
			assert(not a.is_moving() and not b.is_moving(), "B2 must finish within six seconds.")
		for cube_id: String in button_targets:
			var cube_data := source_entities[cube_id] as Dictionary
			assert(cube_data.get("__identifier", "") == "MoveableCube")
			var destinations := _linked_ids(cube_data)
			assert(destinations.size() == 1, "A button-driven cube must have exactly one next-cube destination.")
			var cube := level.get_entity(cube_id) as MoveableCube
			assert(cube != null)
			await _wait_for_motion(cube)
			var target_data := source_entities[destinations[0]] as Dictionary
			var expected_target_rect := _world_rect_from_index(target_data, source_entities)
			assert(cube.get_world_rect().is_equal_approx(expected_target_rect), "Cube %s target mismatch. Actual=%s Expected=%s" % [cube_id, cube.get_world_rect(), expected_target_rect])


func _assert_supported_entity_binding(level: JsonWhiteboxLevel) -> void:
	var has_static_tile_binding := false
	var has_moveable_tile_binding := false
	for child: Node in level.get_children():
		if child is StaticBody2D:
			for supported: Node in child.get_children():
				if supported is Area2D or supported is VineAnchor:
					has_static_tile_binding = true
		if child is MoveableCube:
			for supported: Node in child.get_children():
				if supported is VineAnchor:
					has_moveable_tile_binding = true
	assert(has_static_tile_binding, "Entities resting on a Ground/HardFloor tile must be bound to that tile.")
	assert(has_moveable_tile_binding, "Entities directly beneath a moveable tile must follow that tile.")


func _wait_for_motion(cube: MoveableCube) -> void:
	for _step: int in range(360):
		if not cube.is_moving():
			return
		await physics_frame
	assert(false, "Whitebox moving cube did not reach its target within six seconds.")


func _entity_index(source_data: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for raw_level: Variant in source_data.get("levels", []):
		var source_level := raw_level as Dictionary
		for entity: Dictionary in _entities(source_level):
			var copy := entity.duplicate(true) as Dictionary
			copy["_source_world_offset"] = Vector2(float(source_level.get("worldX", 0)), float(source_level.get("worldY", 0)))
			index[String(entity.get("iid", ""))] = copy
	return index


func _cube_destination_ids(source_entities: Dictionary) -> Dictionary:
	var destinations: Dictionary = {}
	for entity_id: String in source_entities:
		var entity := source_entities[entity_id] as Dictionary
		if entity.get("__identifier", "") != "MoveableCube":
			continue
		for destination_id: String in _linked_ids(entity):
			destinations[destination_id] = true
	return destinations


func _entities(source_level: Dictionary) -> Array[Dictionary]:
	for raw_layer: Variant in source_level.get("layerInstances", []):
		var layer := raw_layer as Dictionary
		if layer.get("__identifier", "") == "Entities":
			var result: Array[Dictionary] = []
			for raw_entity: Variant in layer.get("entityInstances", []):
				result.append(raw_entity as Dictionary)
			return result
	return []


func _world_rect(entity: Dictionary, source_level: Dictionary) -> Rect2:
	var copy := entity.duplicate(true) as Dictionary
	copy["_source_world_offset"] = Vector2(float(source_level.get("worldX", 0)), float(source_level.get("worldY", 0)))
	return _world_rect_from_index(copy, {})


func _world_rect_from_index(entity: Dictionary, _source_entities: Dictionary) -> Rect2:
	var px := entity.get("px", []) as Array
	var world_offset := entity.get("_source_world_offset", Vector2.ZERO) as Vector2
	return Rect2(
		world_offset + Vector2(float(px[0]), float(px[1])),
		Vector2(float(entity.get("width", 16)), float(entity.get("height", 16)))
	)


func _linked_ids(entity: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_field: Variant in entity.get("fieldInstances", []):
		var field := raw_field as Dictionary
		if field.get("__identifier", "") != "Entity_ref":
			continue
		var value: Variant = field.get("__value")
		if value is Dictionary:
			var id := String((value as Dictionary).get("entityIid", ""))
			if not id.is_empty():
				ids.append(id)
		elif value is Array:
			for raw_reference: Variant in value:
				var id := String((raw_reference as Dictionary).get("entityIid", ""))
				if not id.is_empty():
					ids.append(id)
	return ids
