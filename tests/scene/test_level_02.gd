extends SceneTree
## Verify the JSON upper section in the production Level Main composition.

const LEVEL_PATH := "res://scenes/levels/Level_main.tscn"
const SOURCE_PATH := "res://data/Yiguang.json"
const UPPER_BOUNDS := Rect2(-256.0, -128.0, 1008.0, 448.0)
const SOURCE_ANCHOR := Vector2(0.0, 304.0)
const REFERENCE_ANCHOR := Vector2(-262.0, -3.0)
const LAYOUT_SCALE := Vector2(1344.0 / 512.0, 2.5)
# Desktop has three links; the repository copy has older extra links.
# Terrain, entity rectangles and cube destinations agree between the copies.
const DESKTOP_BUTTON_LINKS: Dictionary = {
	"0f859c40-96d0-11f1-9ec0-a7f50fdb1f9d": [],
	"bbbb4660-96d0-11f1-9ec0-d3fb842dd849": ["3005cb90-96d0-11f1-9ec0-231d9bef30a8"],
	"59bb7020-96d0-11f1-9ec0-1f9ad61c57bc": ["de356dc0-96d0-11f1-9ec0-15760920bd18"],
	"17ea7d40-96d0-11f1-9ec0-5b135eaa7d6d": ["3c92f320-96d0-11f1-9ec0-adb2f775b414"],
}
const SAMPLE_OFFSETS: Array[Vector2] = [
	Vector2(0.25, 0.25), Vector2(15.75, 0.25), Vector2(8.0, 8.0),
	Vector2(0.25, 15.75), Vector2(15.75, 15.75),
]

var _checks: int = 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SOURCE_PATH)) != OK:
		_expect(false, "The source JSON must parse")
		_finish()
		return
	var source_levels: Array = (parser.data as Dictionary).get("levels", [])
	var records := _source_entity_records(source_levels)
	var packed := load(LEVEL_PATH) as PackedScene
	if packed == null:
		_expect(false, "The production Level Main scene must load")
		_finish()
		return
	var main := packed.instantiate() as Node2D
	root.add_child(main)
	var level := main.get_node_or_null("Level01/Level02") as Node2D
	var player := main.get_node_or_null("Level01/Actors/Player") as Player
	if level == null or player == null:
		_expect(false, "Level Main nests the upper section under the playable Level01")
		main.queue_free()
		_finish()
		return
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	_expect(not level is HandbuiltLevel, "The upper section shares Level01 lifecycle ownership")
	_verify_upper_ground(level, _source_cells(source_levels, records))
	_verify_upper_cubes(level, records)
	await _verify_upper_thorns(level, records)
	await _verify_upper_buttons(level, player, records)
	main.queue_free()
	await process_frame
	_finish()


func _source_cells(source_levels: Array, records: Dictionary) -> Dictionary:
	var excluded_rects: Array[Rect2] = []
	for record: Dictionary in records.values():
		if record["identifier"] in ["MoveableCube", "Door"]:
			excluded_rects.append(record["rect"] as Rect2)
	var cells: Dictionary = {}
	for raw_level: Variant in source_levels:
		var source := raw_level as Dictionary
		var ground := _find_named(source.get("layerInstances", []), "__identifier", "Ground")
		var width := int(ground.get("__cWid", 0))
		var values: Array = ground.get("intGridCsv", [])
		_expect(width > 0 and int(ground.get("__gridSize", 0)) == 16, "Source terrain uses the authored 16-pixel grid")
		if width <= 0:
			continue
		var world_origin := Vector2(float(source.get("worldX", 0)), float(source.get("worldY", 0)))
		for index: int in range(values.size()):
			var origin := world_origin + Vector2(index % width, index / width) * 16.0
			if not UPPER_BOUNDS.has_point(origin):
				continue
			var covered := false
			for excluded: Rect2 in excluded_rects:
				if excluded.intersects(Rect2(origin, Vector2(16.0, 16.0))):
					covered = true
					break
			cells[Vector2i(origin)] = 0 if covered else int(values[index])
	return cells


func _verify_upper_ground(level: Node2D, expected_cells: Dictionary) -> void:
	var pieces: Array[Dictionary] = []
	var accepted_bodies: Dictionary = {}
	for child: Node in level.get_node("Geometry/Terrain/UpperTerrain").get_children():
		var piece := child as TerrainPiece
		if piece == null:
			continue
		var source_rect: Rect2 = piece.get_meta(&"source_world_rect", Rect2())
		var value := int(piece.get_meta(&"source_int_grid", 0))
		var mapped := _map_rect(source_rect)
		var inset := 6.5 if source_rect.size.x >= source_rect.size.y else 0.0
		var collision_rect := Rect2(mapped.position + Vector2(0.0, inset), mapped.size - Vector2(0.0, inset))
		_expect(value in [1, 3] and UPPER_BOUNDS.encloses(source_rect), "%s has an upper terrain source rectangle" % piece.name)
		_expect(_on_grid(source_rect.position) and _on_grid(source_rect.size), "%s source coverage is grid aligned" % piece.name)
		_expect(_rect_close(piece.global_transform * Rect2(Vector2.ZERO, piece.piece_size), mapped), "%s follows the Floor2 affine mapping" % piece.name)
		_expect(is_equal_approx(piece.art_scale_multiplier, 0.4), "%s uses Level01 artwork density" % piece.name)
		_expect(is_equal_approx(piece.collision_top_inset, inset), "%s uses the Level01 floor inset or full wall collision" % piece.name)
		_expect(piece.can_root() == (value == 1), "%s preserves Ground versus HardFloor rooting" % piece.name)
		var body := piece
		accepted_bodies[body.get_instance_id()] = true
		var polygon := body.get_node("CollisionPolygon2D") as CollisionPolygon2D
		_expect(not polygon.disabled and _polygon_matches(polygon, collision_rect), "%s has the mapped collision polygon" % piece.name)
		pieces.append({"source": source_rect, "collision": collision_rect, "value": value})
	_expect(pieces.size() == 15, "The upper section contains fourteen Ground pieces and one HardFloor")
	var damage := level.get_node("Geometry/Hazards/UpperDamage01") as HazardArea
	var damage_source: Rect2 = damage.get_meta(&"source_world_rect", Rect2())
	var damage_shape := damage.get_node("CollisionShape2D") as CollisionShape2D
	_expect(damage_source.is_equal_approx(Rect2(176.0, 256.0, 32.0, 32.0)), "Four source Damage cells form the authored hazard")
	_expect(not damage_shape.disabled and _rect_close(damage_shape.global_transform * damage_shape.shape.get_rect(), _map_rect(damage_source)), "The IntGrid damage trigger follows the affine mapping")
	pieces.append({"source": damage_source, "collision": _map_rect(damage_source), "value": 2})
	var world_query := PhysicsPointQueryParameters2D.new()
	world_query.collision_mask = 1
	world_query.collide_with_areas = false
	var damage_query := PhysicsPointQueryParameters2D.new()
	damage_query.collision_mask = 32
	damage_query.collide_with_bodies = false
	damage_query.collide_with_areas = true
	var accepted_hazards: Dictionary = {damage.get_instance_id(): true}
	var space := level.get_world_2d().direct_space_state
	var counts := Vector3i.ZERO
	for row: int in range(28):
		for column: int in range(63):
			var cell_origin := UPPER_BOUNDS.position + Vector2(column, row) * 16.0
			var expected := int(expected_cells.get(Vector2i(cell_origin), 0))
			if expected > 0:
				counts[expected - 1] += 1
			var coverage: Array[Dictionary] = []
			for piece: Dictionary in pieces:
				if (piece["source"] as Rect2).has_point(cell_origin + Vector2(8.0, 8.0)):
					coverage.append(piece)
			var matches := coverage.size() == (0 if expected == 0 else 1)
			if coverage.size() == 1:
				matches = matches and int(coverage[0]["value"]) == expected
			for offset: Vector2 in SAMPLE_OFFSETS:
				var world_point := _map_point(cell_origin + offset)
				var expected_solid := false
				for piece: Dictionary in coverage:
					if int(piece["value"]) in [1, 3] and (piece["collision"] as Rect2).has_point(world_point):
						expected_solid = true
				world_query.position = world_point
				damage_query.position = world_point
				# Existing Level01 terrain and dynamic actors are outside this source oracle.
				var solids := _accepted_hits(space.intersect_point(world_query, 128), accepted_bodies)
				matches = matches and (not solids.is_empty()) == expected_solid
				for body: Node in solids:
					matches = matches and body.call(&"can_root") == (expected == 1)
				var hazards := _accepted_hits(space.intersect_point(damage_query, 128), accepted_hazards)
				matches = matches and (not hazards.is_empty()) == (expected == 2)
			_expect(matches, "Mapped source cell %s preserves value %d, cutouts and floor inset" % [cell_origin, expected])
	_expect(counts == Vector3i(94, 4, 1), "The source oracle contains 94 Ground, 4 Damage and 1 HardFloor cells after cube cutouts")


func _verify_upper_cubes(level: Node2D, records: Dictionary) -> void:
	var destination_ids: Dictionary = {}
	for record: Dictionary in records.values():
		if record["identifier"] == "MoveableCube":
			for target_id: String in record["links"]:
				destination_ids[target_id] = true
	var expected_ids: Dictionary = {}
	for source_iid: String in records:
		var record: Dictionary = records[source_iid]
		if record["identifier"] == "MoveableCube" and not destination_ids.has(source_iid) and (record["rect"] as Rect2).intersects(UPPER_BOUNDS):
			expected_ids[source_iid] = record["rect"]
	var actual_ids: Dictionary = {}
	for node: Node in level.find_children("*", "", true, false):
		if not node is MoveableCube:
			continue
		var cube := node as MoveableCube
		var source_iid := String(cube.get_meta(&"source_iid", ""))
		_expect(not destination_ids.has(source_iid), "Cube destination %s is not a second actor" % source_iid)
		_expect(expected_ids.has(source_iid) and not actual_ids.has(source_iid), "Cube %s is a unique upper source actor" % source_iid)
		actual_ids[source_iid] = cube
		if expected_ids.has(source_iid):
			_expect(_rect_close(cube.get_world_rect(), _map_rect(expected_ids[source_iid] as Rect2)), "Cube %s has its mapped initial rectangle" % source_iid)
			var destination_id := String((records[source_iid]["links"] as Array)[0])
			var target: Rect2 = cube.call(&"get_target_world_rect")
			_expect(_rect_close(target, _map_rect(records[destination_id]["rect"] as Rect2)), "Cube %s exposes the mapped authored destination" % source_iid)
	_expect(expected_ids.size() == 6 and actual_ids.size() == 6, "Exactly six active cubes are restored")
	for source_iid: String in expected_ids:
		_expect(actual_ids.has(source_iid), "Source cube %s has a runtime actor" % source_iid)


func _verify_upper_buttons(level: Node2D, player: Player, records: Dictionary) -> void:
	var upper := level.get_node("Geometry/UpperEntities") as Node2D
	var connections: Dictionary = upper.get(&"button_connections")
	var buttons: Dictionary = {}
	var actual_links: Dictionary = {}
	var cubes: Dictionary = {}
	var before: Dictionary = {}
	for node: Node in upper.find_children("*", "", true, false):
		var source_iid := String(node.get_meta(&"source_iid", ""))
		if node is TriggerButton:
			buttons[source_iid] = node
			actual_links[source_iid] = []
		elif node is MoveableCube:
			cubes[source_iid] = node
			before[source_iid] = (node as MoveableCube).get_world_rect()
	var link_count := 0
	for raw_button_path: Variant in connections:
		var button := upper.get_node(NodePath(String(raw_button_path))) as TriggerButton
		var source_iid := String(button.get_meta(&"source_iid", ""))
		var target_ids: Array[String] = []
		for raw_target_path: Variant in connections[raw_button_path]:
			var target := upper.get_node(NodePath(String(raw_target_path))) as MoveableCube
			_expect(target != null, "Button %s directly targets the reusable cube" % source_iid)
			if target != null:
				target_ids.append(String(target.get_meta(&"source_iid", "")))
			link_count += 1
		actual_links[source_iid] = target_ids
	_expect(buttons.size() == 4 and link_count == 3, "Four desktop buttons retain exactly three authored connections")
	for source_iid: String in DESKTOP_BUTTON_LINKS:
		_expect(actual_links.get(source_iid, null) == DESKTOP_BUTTON_LINKS[source_iid], "Button %s preserves desktop links, including the unassigned button" % source_iid)
	var activated_iid := "de356dc0-96d0-11f1-9ec0-15760920bd18"
	var activated := cubes.get(activated_iid) as MoveableCube
	var button := buttons.get("59bb7020-96d0-11f1-9ec0-1f9ad61c57bc") as TriggerButton
	if activated == null or button == null:
		_expect(false, "The authored short platform and its button must exist")
		return
	var destination_id := String((records[activated_iid]["links"] as Array)[0])
	var destination := _map_rect(records[destination_id]["rect"] as Rect2)
	_expect(button.press(player), "Pressing the authored button starts its local action")
	for frame_index: int in range(180):
		await physics_frame
		if not activated.is_moving() and _rect_close(activated.get_world_rect(), destination):
			break
	_expect(_rect_close(activated.get_world_rect(), destination), "The pressed button moves its platform to the mapped source destination")
	for source_iid: String in cubes:
		if source_iid != activated_iid:
			_expect(_rect_close((cubes[source_iid] as MoveableCube).get_world_rect(), before[source_iid] as Rect2), "The button leaves unrelated cube %s still" % source_iid)


func _verify_upper_thorns(level: Node2D, records: Dictionary) -> void:
	var machines: Array[DamageMachine] = []
	for node: Node in level.get_node("Geometry/UpperEntities/Hazards").get_children():
		if node is DamageMachine:
			machines.append(node as DamageMachine)
			node.set_physics_process(false)
	# Keep each sampled center stationary while the physics server synchronizes.
	await physics_frame
	await physics_frame
	_expect(machines.size() == 2, "Both source moving thorns are present")
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 32
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var space := level.get_world_2d().direct_space_state
	for machine: DamageMachine in machines:
		var source_iid := String(machine.get_meta(&"source_iid", ""))
		var source_rect: Rect2 = records[source_iid]["rect"]
		var size := _map_rect(source_rect).size
		var expected := Rect2(machine.global_position - size * 0.5, size)
		var art := machine.get_node("ThornArtwork") as Sprite2D
		var collision := machine.get_node("CollisionShape2D") as CollisionShape2D
		_expect(_rect_close(art.global_transform * art.get_rect(), expected), "%s artwork matches the mapped source dimensions" % machine.name)
		_expect(not collision.disabled and _rect_close(collision.global_transform * collision.shape.get_rect(), expected), "%s collision bounds match the mapped source dimensions" % machine.name)
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			for fraction: float in [0.9, 1.1]:
				query.position = machine.global_position + direction * size * 0.5 * fraction
				var detected := false
				for hit: Dictionary in space.intersect_point(query, 128):
					if hit.get("collider") == machine:
						detected = true
				# Inner samples lie beyond the old radius-8 collision on both axes.
				_expect(detected == (fraction < 1.0), "%s detects only points inside its mapped edge: %s at %.1f" % [machine.name, direction, fraction])
		machine.set_physics_process(true)


func _source_entity_records(source_levels: Array) -> Dictionary:
	var records: Dictionary = {}
	for raw_level: Variant in source_levels:
		var source := raw_level as Dictionary
		var world_offset := Vector2(float(source.get("worldX", 0)), float(source.get("worldY", 0)))
		var entity_layer := _find_named(source.get("layerInstances", []), "__identifier", "Entities")
		for raw_entity: Variant in entity_layer.get("entityInstances", []):
			var entity := raw_entity as Dictionary
			var links: Array[String] = []
			for raw_field: Variant in entity.get("fieldInstances", []):
				var field := raw_field as Dictionary
				if field.get("__identifier", "") != "Entity_ref":
					continue
				var value: Variant = field.get("__value")
				if value is Dictionary:
					links.append(String((value as Dictionary).get("entityIid", "")))
				elif value is Array:
					for raw_reference: Variant in value:
						links.append(String((raw_reference as Dictionary).get("entityIid", "")))
			var px: Array = entity.get("px", [0, 0])
			var rect := Rect2(world_offset + Vector2(float(px[0]), float(px[1])), Vector2(float(entity.get("width", 0)), float(entity.get("height", 0))))
			records[String(entity.get("iid", ""))] = {"identifier": String(entity.get("__identifier", "")), "rect": rect, "links": links}
	return records


func _accepted_hits(hits: Array[Dictionary], accepted: Dictionary) -> Array[Node]:
	var result: Array[Node] = []
	for hit: Dictionary in hits:
		var collider := hit.get("collider") as Node
		if collider != null and accepted.has(collider.get_instance_id()):
			result.append(collider)
	return result


func _polygon_matches(polygon: CollisionPolygon2D, expected: Rect2) -> bool:
	var corners := PackedVector2Array([expected.position, Vector2(expected.end.x, expected.position.y), expected.end, Vector2(expected.position.x, expected.end.y)])
	if polygon.polygon.size() != 4:
		return false
	for index: int in range(4):
		if (polygon.global_transform * polygon.polygon[index]).distance_to(corners[index]) > 0.02:
			return false
	return true


func _map_point(point: Vector2) -> Vector2:
	return REFERENCE_ANCHOR + (point - SOURCE_ANCHOR) * LAYOUT_SCALE


func _map_rect(rect: Rect2) -> Rect2:
	return Rect2(_map_point(rect.position), rect.size * LAYOUT_SCALE)


func _rect_close(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) < 0.02 and actual.size.distance_to(expected.size) < 0.02


func _on_grid(point: Vector2) -> bool:
	return is_zero_approx(fposmod(point.x, 16.0)) and is_zero_approx(fposmod(point.y, 16.0))


func _find_named(entries: Array, key: String, identifier: String) -> Dictionary:
	for raw_entry: Variant in entries:
		var entry := raw_entry as Dictionary
		if entry.get(key, "") == identifier:
			return entry
	return {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("LEVEL 02 MAPPED UPPER SPACE: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
