class_name JsonWhiteboxLevel
extends Node2D
## Runtime whitebox generated from LDtk data. World-space instance rectangles are authoritative.

const SOURCE_PATH := "res://data/Yiguang.json"
const GRID_SIZE := 16.0
const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const ROOTABLE_SURFACE_SCENE: PackedScene = preload("res://features/level/rootable_surface.tscn")
const HAZARD_SCENE: PackedScene = preload("res://features/level/hazard.tscn")
const NUTRITION_SCENE: PackedScene = preload("res://features/level/nutrition_tank.tscn")
const TOXIN_RESOURCE_SCENE: PackedScene = preload("res://features/level/toxin_resource.tscn")
const TOXIN_ZONE_SCENE: PackedScene = preload("res://features/level/toxin_zone.tscn")
const WIND_SCENE: PackedScene = preload("res://features/level/wind_zone.tscn")
const RING_SCENE: PackedScene = preload("res://features/abilities/vine_anchor.tscn")
const CUBE_SCENE: PackedScene = preload("res://features/level/moveable_cube.tscn")
const BUTTON_SCENE: PackedScene = preload("res://features/level/whitebox_button.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://features/level/checkpoint.tscn")
const DAMAGE_MACHINE_SCENE: PackedScene = preload("res://features/level/damage_machine.tscn")

const DAMAGE_MACHINE_TRAVEL_DISTANCE := 32.0
const DAMAGE_MACHINE_TRAVEL_SPEED := 64.0
const CAMERA_DRAG_MARGIN_HORIZONTAL := 0.2
const CAMERA_DRAG_MARGIN_VERTICAL := 0.25
const SUPPORT_EPSILON := 0.01

var _player: Player
var _spawn_position := Vector2.ZERO
var _camera_rect := Rect2(Vector2.ZERO, Vector2(336.0, 160.0))
var _world_bounds := Rect2()
var _has_world_bounds := false
var _entity_nodes: Dictionary = {}
var _entity_source_rects: Dictionary = {}
var _entity_identifiers: Dictionary = {}
var _entity_links: Dictionary = {}
var _destination_cube_ids: Dictionary = {}
var _surface_tiles: Array[Dictionary] = []
var _visual_rectangles: Array[Dictionary] = []
var _entity_labels: Array[Dictionary] = []
var _data_issues: PackedStringArray = []


func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.name = "Player"
	add_child(_player)
	_build_from_source()
	_player.global_position = _spawn_position
	_create_camera()
	queue_redraw()


func get_entity(entity_iid: String) -> Node:
	return _entity_nodes.get(entity_iid) as Node


func get_source_rect(entity_iid: String) -> Rect2:
	return _entity_source_rects.get(entity_iid, Rect2()) as Rect2


func get_data_issues() -> PackedStringArray:
	return _data_issues


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()


func _build_from_source() -> void:
	var source_text := FileAccess.get_file_as_string(SOURCE_PATH)
	var parser := JSON.new()
	if parser.parse(source_text) != OK:
		push_error("Cannot parse whitebox source: %s" % parser.get_error_message())
		return
	var data := parser.data as Dictionary
	if data.is_empty():
		push_error("Whitebox source is empty.")
		return
	_index_source_data(data)
	var cube_rectangles := _collect_cube_rectangles(data)
	for raw_level: Variant in data.get("levels", []):
		var level := raw_level as Dictionary
		_build_level_geometry(level, cube_rectangles)
		_build_level_entities(level)
	_bind_entities_to_supporting_geometry()
	_wire_data_mechanisms()


func _index_source_data(data: Dictionary) -> void:
	for raw_level: Variant in data.get("levels", []):
		var level := raw_level as Dictionary
		var world_offset := Vector2(float(level.get("worldX", 0)), float(level.get("worldY", 0)))
		var level_rect := Rect2(world_offset, Vector2(float(level.get("pxWid", 0)), float(level.get("pxHei", 0))))
		if _has_world_bounds:
			_world_bounds = _world_bounds.merge(level_rect)
		else:
			_world_bounds = level_rect
			_has_world_bounds = true
		for raw_layer: Variant in level.get("layerInstances", []):
			var layer := raw_layer as Dictionary
			if layer.get("__identifier", "") != "Entities":
				continue
			for raw_entity: Variant in layer.get("entityInstances", []):
				var entity := raw_entity as Dictionary
				var entity_id := String(entity.get("iid", ""))
				var identifier := String(entity.get("__identifier", ""))
				_entity_source_rects[entity_id] = _entity_rect(entity, world_offset)
				_entity_identifiers[entity_id] = identifier
				_entity_links[entity_id] = _linked_entity_ids(entity)
				if identifier == "Camera":
					_camera_rect = _entity_rect(entity, world_offset)
	for source_id: String in _entity_links:
		if _entity_identifiers.get(source_id) != "MoveableCube":
			continue
		for destination_id: String in _entity_links[source_id]:
			_destination_cube_ids[destination_id] = true


func _collect_cube_rectangles(data: Dictionary) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for raw_level: Variant in data.get("levels", []):
		var level := raw_level as Dictionary
		var world_offset := Vector2(float(level.get("worldX", 0)), float(level.get("worldY", 0)))
		for raw_layer: Variant in level.get("layerInstances", []):
			var layer := raw_layer as Dictionary
			if layer.get("__identifier", "") != "Entities":
				continue
			for raw_entity: Variant in layer.get("entityInstances", []):
				var entity := raw_entity as Dictionary
				if entity.get("__identifier", "") == "MoveableCube":
					rectangles.append(_entity_rect(entity, world_offset))
	return rectangles


func _build_level_geometry(level: Dictionary, cube_rectangles: Array[Rect2]) -> void:
	var world_offset := Vector2(float(level.get("worldX", 0)), float(level.get("worldY", 0)))
	for raw_layer: Variant in level.get("layerInstances", []):
		var layer := raw_layer as Dictionary
		if layer.get("__identifier", "") != "Ground":
			continue
		var width := int(layer.get("__cWid", 0))
		var values := layer.get("intGridCsv", []) as Array
		for index: int in range(values.size()):
			var value := int(values[index])
			if value == 0:
				continue
			var cell_position := world_offset + Vector2(float(index % width) * GRID_SIZE, float(index / width) * GRID_SIZE)
			var cell_rect := Rect2(cell_position, Vector2.ONE * GRID_SIZE)
			if _overlaps_cube(cell_rect, cube_rectangles):
				continue
			match value:
				1:
					_create_surface(cell_rect, true, Color("#31543b"), "Ground")
				2:
					_create_hazard(cell_rect, Color("#bd3f4a"), "Damage")
				3:
					_create_surface(cell_rect, false, Color("#808080"), "HardFloor")


func _build_level_entities(level: Dictionary) -> void:
	var world_offset := Vector2(float(level.get("worldX", 0)), float(level.get("worldY", 0)))
	for raw_layer: Variant in level.get("layerInstances", []):
		var layer := raw_layer as Dictionary
		if layer.get("__identifier", "") != "Entities":
			continue
		for raw_entity: Variant in layer.get("entityInstances", []):
			_spawn_entity(raw_entity as Dictionary, world_offset)


func _spawn_entity(entity: Dictionary, world_offset: Vector2) -> void:
	var identifier := String(entity.get("__identifier", ""))
	var entity_id := String(entity.get("iid", ""))
	var rect := _entity_rect(entity, world_offset)
	match identifier:
		"Start":
			_spawn_position = rect.get_center()
			_entity_labels.append({"text": "Start", "position": rect.position})
		"Camera":
			pass
		"GrowDrug":
			var nutrition := NUTRITION_SCENE.instantiate() as NutritionTank
			_configure_area(nutrition, rect)
			add_child(nutrition)
			_register_entity(entity_id, nutrition)
			_visual_rectangles.append({"rect": rect, "color": Color("#65d46e"), "label": "Grow"})
		"UnGrowDrug":
			var toxin_resource := TOXIN_RESOURCE_SCENE.instantiate() as Area2D
			_configure_area(toxin_resource, rect)
			add_child(toxin_resource)
			_register_entity(entity_id, toxin_resource)
			_visual_rectangles.append({"rect": rect, "color": Color("#9861c8"), "label": "Toxin"})
		"Frog":
			var frog := TOXIN_ZONE_SCENE.instantiate() as ToxinZone
			_configure_area(frog, rect)
			frog.actor_entered.connect(func(actor: Node2D) -> void: _on_frog_actor_entered(frog, actor))
			frog.actor_exited.connect(func(actor: Node2D) -> void: _on_frog_actor_exited(frog, actor))
			add_child(frog)
			_register_entity(entity_id, frog)
			_entity_labels.append({"text": "Frog", "position": rect.position + Vector2(0.0, -4.0)})
		"Door":
			var door := _make_cube(rect)
			add_child(door)
			_register_entity(entity_id, door)
		"Button":
			var button := BUTTON_SCENE.instantiate() as WhiteboxButton
			button.button_size = rect.size
			button.global_position = rect.position
			add_child(button)
			_register_entity(entity_id, button)
			_entity_labels.append({"text": "Button", "position": rect.position + Vector2(0.0, -4.0)})
		"DamageMachine":
			var machine := DAMAGE_MACHINE_SCENE.instantiate() as Area2D
			machine.global_position = rect.get_center()
			machine.set(&"travel_distance", DAMAGE_MACHINE_TRAVEL_DISTANCE)
			machine.set(&"travel_speed", DAMAGE_MACHINE_TRAVEL_SPEED)
			add_child(machine)
			machine.actor_killed.connect(_on_machine_actor_killed)
			_register_entity(entity_id, machine)
		"Wind":
			var wind := WIND_SCENE.instantiate() as WindZone
			wind.zone_size = rect.size
			wind.global_position = rect.position
			add_child(wind)
			_register_entity(entity_id, wind)
		"Ring":
			var ring := RING_SCENE.instantiate() as Node2D
			ring.global_position = rect.get_center()
			add_child(ring)
			_register_entity(entity_id, ring)
		"MoveableCube":
			if _destination_cube_ids.has(entity_id):
				_visual_rectangles.append({"rect": rect, "color": Color("#49634c", 0.35), "label": "Cube target"})
				return
			var cube := _make_cube(rect)
			add_child(cube)
			_register_entity(entity_id, cube)
			_entity_labels.append({"text": "Cube", "position": rect.position + Vector2(0.0, -4.0)})
		"Checkpoint":
			var checkpoint := CHECKPOINT_SCENE.instantiate() as Area2D
			_configure_area(checkpoint, rect)
			checkpoint.actor_checkpoint_reached.connect(_on_checkpoint_reached)
			add_child(checkpoint)
			_register_entity(entity_id, checkpoint)
		_:
			_add_data_issue("Unhandled source entity type: %s" % identifier)


func _wire_data_mechanisms() -> void:
	for entity_id: String in _entity_links:
		if _entity_identifiers.get(entity_id) != "Button":
			continue
		var button := get_entity(entity_id) as WhiteboxButton
		if button == null:
			_add_data_issue("Button %s has no runtime instance." % entity_id)
			continue
		button.pressed.connect(_on_button_pressed.bind(entity_id))


func _on_button_pressed(_button: WhiteboxButton, _actor: Node2D, button_id: String) -> void:
	for cube_id: String in _entity_links.get(button_id, []):
		var cube := get_entity(cube_id) as MoveableCube
		if cube == null:
			_add_data_issue("Button %s references non-runtime MoveableCube %s." % [button_id, cube_id])
			continue
		var destinations: Array[String] = _entity_links.get(cube_id, [])
		if destinations.size() != 1:
			_add_data_issue("MoveableCube %s must reference exactly one destination; found %d." % [cube_id, destinations.size()])
			continue
		var target_rect := get_source_rect(destinations[0])
		if target_rect.size.is_zero_approx():
			_add_data_issue("MoveableCube %s destination %s has no source rectangle." % [cube_id, destinations[0]])
			continue
		cube.move_to_rect(target_rect)


func _bind_entities_to_supporting_geometry() -> void:
	for cube_id: String in _entity_nodes:
		var cube := _entity_nodes[cube_id] as MoveableCube
		if cube == null:
			continue
		var cube_rect := get_source_rect(cube_id)
		for entity_id: String in _entity_nodes:
			var entity := _entity_nodes[entity_id] as Node2D
			if entity == null or entity == cube or entity.get_parent() != self:
				continue
			if _entity_identifiers.get(entity_id) in ["MoveableCube", "Door"]:
				continue
			if _is_directly_below(get_source_rect(entity_id), cube_rect):
				entity.reparent(cube, true)
	for entity_id: String in _entity_nodes:
		var entity := _entity_nodes[entity_id] as Node2D
		if entity == null or entity.get_parent() != self:
			continue
		if _entity_identifiers.get(entity_id) in ["MoveableCube", "Door"]:
			continue
		for tile_entry: Dictionary in _surface_tiles:
			if _rests_on(get_source_rect(entity_id), tile_entry["rect"] as Rect2):
				entity.reparent(tile_entry["node"] as Node, true)
				break


func _rests_on(entity_rect: Rect2, support_rect: Rect2) -> bool:
	return (
		is_equal_approx(entity_rect.end.y, support_rect.position.y)
		and entity_rect.position.x < support_rect.end.x - SUPPORT_EPSILON
		and entity_rect.end.x > support_rect.position.x + SUPPORT_EPSILON
	)


func _is_directly_below(entity_rect: Rect2, support_rect: Rect2) -> bool:
	return (
		is_equal_approx(entity_rect.position.y, support_rect.end.y)
		and entity_rect.position.x < support_rect.end.x - SUPPORT_EPSILON
		and entity_rect.end.x > support_rect.position.x + SUPPORT_EPSILON
	)


func _create_surface(rect: Rect2, allows_rooting: bool, color: Color, label: String) -> void:
	var surface := ROOTABLE_SURFACE_SCENE.instantiate() as StaticBody2D
	surface.allows_rooting = allows_rooting
	surface.global_position = rect.position
	_configure_body_shape(surface, rect.size)
	add_child(surface)
	_surface_tiles.append({"node": surface, "rect": rect})
	_visual_rectangles.append({"rect": rect, "color": color, "label": label})


func _create_hazard(rect: Rect2, color: Color, label: String) -> void:
	var hazard := HAZARD_SCENE.instantiate() as Hazard
	hazard.global_position = rect.position
	_configure_area(hazard, rect)
	hazard.actor_killed.connect(_on_hazard_actor_killed)
	add_child(hazard)
	_visual_rectangles.append({"rect": rect, "color": color, "label": label})


func _make_cube(rect: Rect2) -> MoveableCube:
	var cube := CUBE_SCENE.instantiate() as MoveableCube
	cube.cube_size = rect.size
	cube.global_position = rect.position
	return cube


func _configure_area(area: Area2D, rect: Rect2) -> void:
	area.global_position = rect.position
	var collision := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	_make_collision_shape_unique(collision)
	var shape := collision.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision.shape = shape
	shape.size = rect.size
	collision.position = rect.size * 0.5


func _configure_body_shape(body: StaticBody2D, size: Vector2) -> void:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	_make_collision_shape_unique(collision)
	var shape := collision.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision.shape = shape
	shape.size = size
	collision.position = size * 0.5


func _make_collision_shape_unique(collision: CollisionShape2D) -> void:
	if collision.shape != null:
		collision.shape = collision.shape.duplicate(true)


func _overlaps_cube(cell_rect: Rect2, cube_rectangles: Array[Rect2]) -> bool:
	for cube_rect: Rect2 in cube_rectangles:
		if cell_rect.intersects(cube_rect):
			return true
	return false


func _entity_rect(entity: Dictionary, world_offset: Vector2) -> Rect2:
	var px := entity.get("px", []) as Array
	return Rect2(
		world_offset + Vector2(float(px[0]), float(px[1])),
		Vector2(float(entity.get("width", GRID_SIZE)), float(entity.get("height", GRID_SIZE)))
	)


func _linked_entity_ids(entity: Dictionary) -> Array[String]:
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
				var reference := raw_reference as Dictionary
				var id := String(reference.get("entityIid", ""))
				if not id.is_empty():
					ids.append(id)
	return ids


func _register_entity(entity_id: String, node: Node) -> void:
	_entity_nodes[entity_id] = node


func _add_data_issue(message: String) -> void:
	if message in _data_issues:
		return
	_data_issues.append(message)
	push_warning(message)


func _on_frog_actor_entered(frog: ToxinZone, actor: Node2D) -> void:
	if actor == _player:
		_player.enter_toxin(frog)


func _on_frog_actor_exited(frog: ToxinZone, actor: Node2D) -> void:
	if actor == _player:
		_player.exit_toxin(frog)


func _on_hazard_actor_killed(actor: Node2D) -> void:
	if actor == _player:
		_respawn_player()


func _on_machine_actor_killed(actor: Node2D) -> void:
	if actor == _player:
		_respawn_player()


func _on_checkpoint_reached(actor: Node2D, position: Vector2) -> void:
	if actor == _player:
		_spawn_position = position


func _respawn_player() -> void:
	_player.cancel_actions()
	_player.global_position = _spawn_position
	_player.velocity = Vector2.ZERO


func _create_camera() -> void:
	var camera := Camera2D.new()
	camera.name = "Camera"
	# The source Camera instance is 336 x 160 world pixels at the 1344 x 640 reference viewport.
	camera.zoom = Vector2(4.0, 4.0)
	camera.position = _camera_rect.get_center() - _player.global_position
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.drag_left_margin = CAMERA_DRAG_MARGIN_HORIZONTAL
	camera.drag_right_margin = CAMERA_DRAG_MARGIN_HORIZONTAL
	camera.drag_top_margin = CAMERA_DRAG_MARGIN_VERTICAL
	camera.drag_bottom_margin = CAMERA_DRAG_MARGIN_VERTICAL
	camera.position_smoothing_enabled = false
	if _has_world_bounds:
		camera.limit_left = int(_world_bounds.position.x)
		camera.limit_top = int(_world_bounds.position.y)
		camera.limit_right = int(_world_bounds.end.x)
		camera.limit_bottom = int(_world_bounds.end.y)
	_player.add_child(camera)


func _draw() -> void:
	for entry: Dictionary in _visual_rectangles:
		var rect := entry["rect"] as Rect2
		var color := entry["color"] as Color
		draw_rect(rect, color)
	for entry: Dictionary in _entity_labels:
		draw_string(ThemeDB.fallback_font, entry["position"] as Vector2, String(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)
