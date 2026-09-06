extends SceneTree
## Test authored attachments without treating historical JSON coordinates as an oracle.

const MAIN_SCENE := preload("res://scenes/levels/Level_main.tscn")
const CUBE_SCENE := preload("res://features/level/moveable_cube.tscn")
const RING_SCENE := preload("res://features/abilities/vine_ring.tscn")
const TOLERANCE := 0.03

var _checks: int = 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_authored_bindings()
	await _verify_reusable_motion()
	print("MOVEABLE CUBE ATTACHMENTS: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _verify_authored_bindings() -> void:
	var main := MAIN_SCENE.instantiate() as Node2D
	var upper := main.get_node_or_null("Level01/Level02/Geometry/UpperEntities") as Node2D
	_expect(upper != null, "The current Level Main exposes its authored upper attachments")
	if upper == null:
		main.free()
		return
	var bindings: Dictionary = upper.get(&"attachment_connections")
	var hidden_paths: Array = upper.get(&"hidden_until_arrival")
	var attachments: Array[Dictionary] = []
	var bound_rings: Array[VineRing] = []
	var cubes: Array[MoveableCube] = []
	for ring_path: NodePath in bindings:
		var ring := upper.get_node_or_null(ring_path) as VineRing
		_expect(ring != null, "Authored attachment path %s resolves to a Ring" % ring_path)
		if ring == null:
			continue
		var cube := upper.get_node_or_null(bindings[ring_path]) as MoveableCube
		_expect(cube != null, "%s resolves its currently authored supporting Cube" % ring.name)
		if cube == null:
			continue
		var ring_world := _authored_world_transform(ring)
		var cube_world := _authored_world_transform(cube)
		attachments.append({"ring": ring, "cube": cube, "world": ring_world,
			"local": cube_world.affine_inverse() * ring_world, "height": cube.cube_size.y,
			"hidden_until_arrival": hidden_paths.has(ring_path)})
		bound_rings.append(ring)
		if not cubes.has(cube):
			cubes.append(cube)
	_expect(attachments.size() == bindings.size(), "Every currently authored attachment resolves without imposing historical bindings")
	var unbound: Array[Dictionary] = []
	for node: Node in upper.find_children("*", "", true, false):
		var ring := node as VineRing
		if ring != null and not bound_rings.has(ring):
			unbound.append({"ring": ring, "world": _authored_world_transform(ring),
				"available": ring.is_available(), "parent": ring.get_parent()})
	print("Authored attachment coverage: %d Rings on %d Cubes; %d independent Rings" % [attachments.size(), cubes.size(), unbound.size()])
	root.add_child(main)
	var player := main.get_node_or_null("Level01/Actors/Player") as Player
	if player != null:
		player.set_physics_process(false)
	for attachment: Dictionary in attachments:
		var ring := attachment["ring"] as VineRing
		_expect(ring.get_parent() == attachment["cube"], "%s is reparented to its authored Cube" % ring.name)
		_expect(_transform_close(ring.global_transform, attachment["world"] as Transform2D), "%s keeps its hand-edited world transform during binding" % ring.name)
		_expect(ring.is_available() == not bool(attachment["hidden_until_arrival"]), "%s uses its explicitly authored initial availability" % ring.name)
	_verify_unbound_rings(unbound, "ready")
	var targets: Dictionary = {}
	var observations: Dictionary = {}
	for cube: MoveableCube in cubes:
		targets[cube] = cube.call(&"get_target_world_rect")
		var target_rect: Rect2 = cube.get(&"target_rect")
		var target_degrees := float(cube.get(&"target_rotation_degrees"))
		var target_size := Vector2(target_rect.size.y, target_rect.size.x) if is_equal_approx(target_degrees, 90.0) else target_rect.size
		var reference := cube.get_node(cube.get(&"target_reference_path")) as Node2D
		observations[cube] = {"rotation": cube.global_rotation, "size": cube.cube_size,
			"expect_rotation": absf(angle_difference(cube.global_rotation, reference.global_rotation + deg_to_rad(target_degrees))) > 0.01,
			"expect_resize": not cube.cube_size.is_equal_approx(target_size), "rotated": false, "resized": false}
		_expect(cube.activate(), "%s starts its current Inspector-authored motion" % cube.name)
	var ticks := 0
	var moving_samples := 0
	for frame_index: int in range(900):
		await physics_frame
		ticks += 1
		var any_moving := false
		for cube: MoveableCube in cubes:
			any_moving = any_moving or cube.is_moving()
			if cube.is_moving():
				var observation: Dictionary = observations[cube]
				observation["rotated"] = bool(observation["rotated"]) or absf(angle_difference(float(observation["rotation"]), cube.global_rotation)) > 0.01
				observation["resized"] = bool(observation["resized"]) or cube.cube_size.distance_to(observation["size"] as Vector2) > 0.01
		if any_moving:
			moving_samples += 1
		for attachment: Dictionary in attachments:
			_verify_attachment(attachment, "authored motion tick %d" % ticks)
			var ring := attachment["ring"] as VineRing
			var cube := attachment["cube"] as MoveableCube
			var expected_available := not bool(attachment["hidden_until_arrival"]) or not cube.is_moving()
			_expect(ring.is_available() == expected_available, "%s follows its authored availability policy during motion" % ring.name)
		_verify_unbound_rings(unbound, "motion tick %d" % ticks)
		if not any_moving:
			break
	_expect(cubes.is_empty() or moving_samples >= 3, "Authored attachments are sampled through multiple physical motion ticks")
	for cube: MoveableCube in cubes:
		_expect(not cube.is_moving() and _rect_close(cube.get_world_rect(), targets[cube] as Rect2), "%s reaches its current authored destination" % cube.name)
		var observation: Dictionary = observations[cube]
		_expect(not bool(observation["expect_rotation"]) or bool(observation["rotated"]), "%s intended rotation is observed during physical motion" % cube.name)
		_expect(not bool(observation["expect_resize"]) or bool(observation["resized"]), "%s intended resizing is observed during physical motion" % cube.name)
	for attachment: Dictionary in attachments:
		var ring := attachment["ring"] as VineRing
		_expect(ring.is_available() and ring.is_in_group(&"vine_anchor"), "%s becomes usable at the destination" % ring.name)
	_verify_unbound_rings(unbound, "arrival")
	main.queue_free()
	await process_frame


func _verify_unbound_rings(rings: Array[Dictionary], label: String) -> void:
	for record: Dictionary in rings:
		var ring := record["ring"] as VineRing
		_expect(ring.get_parent() == record["parent"] and _transform_close(ring.global_transform, record["world"] as Transform2D), "%s remains independent at its hand-edited world transform during %s" % [ring.name, label])
		_expect(ring.is_available() == bool(record["available"]), "%s preserves its independent availability during %s" % [ring.name, label])


func _verify_reusable_motion() -> void:
	var fixture := Node2D.new()
	fixture.position = Vector2(311.0, 127.0)
	fixture.rotation = 0.2
	fixture.scale = Vector2(1.25, 1.25)
	var cube := CUBE_SCENE.instantiate() as MoveableCube
	cube.position = Vector2(-50.0, 20.0)
	cube.cube_size = Vector2(64.0, 40.0)
	cube.motion_speed = 600.0
	cube.startup_shake_duration = 0.02
	fixture.add_child(cube)
	var ring := RING_SCENE.instantiate() as VineRing
	ring.position = Vector2(-29.0, 81.0)
	ring.rotation = -0.17
	ring.scale = Vector2(0.8, 1.2)
	fixture.add_child(ring)
	root.add_child(fixture)
	var initial_cube := cube.global_transform
	var initial_size := cube.cube_size
	var initial_ring := ring.global_transform
	cube.bind_bottom_attachment(ring)
	_expect(_transform_close(ring.global_transform, initial_ring), "Reusable binding preserves Ring translation, rotation and scale")
	var attachment: Dictionary = {"ring": ring, "cube": cube, "local": ring.transform, "height": cube.cube_size.y}
	var translated := initial_cube.origin + Vector2(96.0, -48.0)
	_expect(cube.move_top_left_to(translated), "The reusable Cube starts translation")
	await _sample_reusable_motion(attachment, "translation")
	_expect(cube.global_position.distance_to(translated) < TOLERANCE, "Translation reaches its requested endpoint")
	var pivot := cube.to_global(Vector2(10.0, 15.0))
	var previous_transform := cube.global_transform
	var expected_rotation := previous_transform.rotated_local(PI * 0.5)
	expected_rotation.origin = pivot + (previous_transform.origin - pivot).rotated(PI * 0.5)
	_expect(cube.rotate_clockwise_about(pivot), "The reusable Cube starts a 90-degree pivot rotation")
	await _sample_reusable_motion(attachment, "rotation")
	_expect(_transform_close(cube.global_transform, expected_rotation), "Pivot rotation reaches its requested transform")
	# A non-swapped size exercises bottom-offset updates during animated resizing.
	var resized := Rect2(cube.global_position + Vector2(72.0, 48.0), Vector2(92.0, 76.0))
	_expect(cube.move_to_rect(resized), "The reusable Cube starts translation and resizing together")
	await _sample_reusable_motion(attachment, "resize")
	_expect(_rect_close(cube.get_world_rect(), resized), "Resizing reaches its requested rectangle")
	cube.reset_platform()
	await physics_frame
	_expect(_transform_close(cube.global_transform, initial_cube) and cube.cube_size.is_equal_approx(initial_size), "Reset restores the Cube's initial transform and size")
	_expect(_transform_close(ring.global_transform, initial_ring), "Reset also restores the attached Ring's original world transform")
	_verify_attachment(attachment, "reset")
	fixture.queue_free()
	await process_frame


func _sample_reusable_motion(attachment: Dictionary, label: String) -> void:
	var cube := attachment["cube"] as MoveableCube
	var samples := 0
	for frame_index: int in range(360):
		await physics_frame
		_verify_attachment(attachment, label)
		samples += 1
		if not cube.is_moving():
			break
	_expect(samples >= 3 and not cube.is_moving(), "%s is sampled across multiple physical ticks and completes" % label)


func _verify_attachment(attachment: Dictionary, label: String) -> void:
	var cube := attachment["cube"] as MoveableCube
	var ring := attachment["ring"] as VineRing
	var local: Transform2D = attachment["local"]
	# Preserve the designer's horizontal and bottom-edge offsets as height changes.
	local.origin.y += cube.cube_size.y - float(attachment["height"])
	_expect(ring.get_parent() == cube and _transform_close(ring.global_transform, cube.global_transform * local), "%s follows Cube transform and bottom offset during %s" % [ring.name, label])


func _authored_world_transform(node: Node2D) -> Transform2D:
	var result := node.transform
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is Node2D:
			result = (ancestor as Node2D).transform * result
		ancestor = ancestor.get_parent()
	return result


func _transform_close(actual: Transform2D, expected: Transform2D) -> bool:
	return actual.origin.distance_to(expected.origin) < TOLERANCE and actual.x.distance_to(expected.x) < 0.001 and actual.y.distance_to(expected.y) < 0.001


func _rect_close(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) < TOLERANCE and actual.size.distance_to(expected.size) < TOLERANCE


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
