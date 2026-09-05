class_name JsonWhiteboxLevel
extends Node2D
## Runtime whitebox generated from the LDtk source data. Instance coordinates stay in world pixels.

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

const C1_ID := "6eaa3900-96d0-11f1-a2bb-61a47c4c3084"
const C2_ID := "3005cb90-96d0-11f1-9ec0-231d9bef30a8"
const C3_ID := "3c92f320-96d0-11f1-9ec0-adb2f775b414"
const C4_ID := "44101060-96d0-11f1-9ec0-dd217176b5ba"
const C5_ID := "de356dc0-96d0-11f1-9ec0-15760920bd18"
const C6_ID := "322a3230-96d0-11f1-9ec0-65ba33f44fa8"
const B1_ID := "0f859c40-96d0-11f1-9ec0-a7f50fdb1f9d"
const B2_ID := "bbbb4660-96d0-11f1-9ec0-d3fb842dd849"
const B3_ID := "59bb7020-96d0-11f1-9ec0-1f9ad61c57bc"
const B4_ID := "17ea7d40-96d0-11f1-9ec0-5b135eaa7d6d"

const C3_C4_HIDDEN_OFFSET := Vector2(0.0, -160.0)
const C5_INITIAL_OFFSET := Vector2(0.0, -128.0)
const DAMAGE_MACHINE_TRAVEL_DISTANCE := 32.0
const DAMAGE_MACHINE_TRAVEL_SPEED := 64.0

var _player: Player
var _spawn_position := Vector2.ZERO
var _entity_nodes: Dictionary = {}
var _cube_source_positions: Dictionary = {}
var _visual_rectangles: Array[Dictionary] = []
var _entity_labels: Array[Dictionary] = []


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
	var cube_rectangles := _collect_cube_rectangles(data)
	for raw_level: Variant in data.get("levels", []):
		var level := raw_level as Dictionary
		_build_level_geometry(level, cube_rectangles)
		_build_level_entities(level)
	_wire_known_mechanisms()


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
				if entity.get("__identifier", "") != "MoveableCube":
					continue
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
			var button := BUTTON_SCENE.instantiate() as Area2D
			button.set(&"button_size", rect.size)
			button.global_position = rect.position
			add_child(button)
			_register_entity(entity_id, button)
			_entity_labels.append({"text": _button_label(entity_id), "position": rect.position + Vector2(0.0, -4.0)})
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
			var cube := _make_cube(rect)
			if entity_id == C3_ID or entity_id == C4_ID:
				cube.global_position += C3_C4_HIDDEN_OFFSET
			elif entity_id == C5_ID:
				cube.global_position += C5_INITIAL_OFFSET
			add_child(cube)
			_register_entity(entity_id, cube)
			_cube_source_positions[entity_id] = rect.position
			_entity_labels.append({"text": _cube_label(entity_id), "position": rect.position + Vector2(0.0, -4.0)})
		"Checkpoint":
			var checkpoint := CHECKPOINT_SCENE.instantiate() as Area2D
			_configure_area(checkpoint, rect)
			checkpoint.actor_checkpoint_reached.connect(_on_checkpoint_reached)
			add_child(checkpoint)
			_register_entity(entity_id, checkpoint)


func _wire_known_mechanisms() -> void:
	var b1 := get_entity(B1_ID) as Area2D
	var b2 := get_entity(B2_ID) as Area2D
	var b3 := get_entity(B3_ID) as Area2D
	var b4 := get_entity(B4_ID) as Area2D
	var c1 := get_entity(C1_ID) as Node2D
	var c2 := get_entity(C2_ID) as Node2D
	var c3 := get_entity(C3_ID) as Node2D
	var c4 := get_entity(C4_ID) as Node2D
	var c5 := get_entity(C5_ID) as Node2D
	var c6 := get_entity(C6_ID) as Node2D
	if b1 != null and c1 != null:
		b1.pressed.connect(func(_button: Area2D, _actor: Node2D) -> void: c1.call(&"rotate_clockwise_about", Vector2(512.0, 304.0)))
	if b2 != null and c2 != null and c6 != null:
		b2.pressed.connect(func(_button: Area2D, _actor: Node2D) -> void:
			var pivot := Vector2(592.0, 176.0)
			var shared_duration := maxf(
				float(c2.call(&"get_rotation_duration", pivot)),
				float(c6.call(&"get_rotation_duration", pivot))
			)
			c2.call(&"rotate_clockwise_about", pivot, 90.0, shared_duration)
			c6.call(&"rotate_clockwise_about", pivot, 90.0, shared_duration)
		)
	if b3 != null and c5 != null:
		b3.pressed.connect(func(_button: Area2D, _actor: Node2D) -> void: _move_c5_to_configured_floor(c5))
	if b4 != null and c3 != null and c4 != null:
		_attach_rings_to_hidden_cube(c3, C3_ID, ["e638aaf0-96d0-11f1-9ec0-47d36b46fa53", "e6afd6c0-96d0-11f1-9ec0-230200d3b3cc"])
		_attach_rings_to_hidden_cube(c4, C4_ID, ["e33e56b0-96d0-11f1-9ec0-eb30919fa281", "e4d80980-96d0-11f1-9ec0-bf3ef0df67ce"])
		b4.pressed.connect(func(_button: Area2D, _actor: Node2D) -> void:
			c3.call(&"move_top_left_to", _cube_source_positions[C3_ID])
			c4.call(&"move_top_left_to", _cube_source_positions[C4_ID])
		)


func _move_c5_to_configured_floor(cube: Node2D) -> void:
	# The JSON position puts C5's lower edge on the confirmed y=304 floor line.
	cube.call(&"move_top_left_to", _cube_source_positions[C5_ID])


func _attach_rings_to_hidden_cube(cube: Node2D, cube_id: String, ring_ids: Array[String]) -> void:
	var source_position := _cube_source_positions[cube_id] as Vector2
	for ring_id: String in ring_ids:
		var ring := get_entity(ring_id) as Node2D
		if ring == null:
			continue
		var source_ring_position := ring.global_position
		ring.reparent(cube, false)
		ring.position = source_ring_position - source_position


func _create_surface(rect: Rect2, allows_rooting: bool, color: Color, label: String) -> void:
	var surface := ROOTABLE_SURFACE_SCENE.instantiate() as StaticBody2D
	surface.set(&"allows_rooting", allows_rooting)
	surface.global_position = rect.position
	_configure_body_shape(surface, rect.size)
	add_child(surface)
	_visual_rectangles.append({"rect": rect, "color": color, "label": label})


func _create_hazard(rect: Rect2, color: Color, label: String) -> void:
	var hazard := HAZARD_SCENE.instantiate() as Hazard
	hazard.global_position = rect.position
	_configure_area(hazard, rect)
	hazard.actor_killed.connect(_on_hazard_actor_killed)
	add_child(hazard)
	_visual_rectangles.append({"rect": rect, "color": color, "label": label})


func _make_cube(rect: Rect2) -> Node2D:
	var cube := CUBE_SCENE.instantiate() as Node2D
	cube.set(&"cube_size", rect.size)
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


func _register_entity(entity_id: String, node: Node) -> void:
	_entity_nodes[entity_id] = node


func _button_label(entity_id: String) -> String:
	match entity_id:
		B1_ID: return "B1"
		B2_ID: return "B2"
		B3_ID: return "B3"
		B4_ID: return "B4"
	return "B?"


func _cube_label(entity_id: String) -> String:
	match entity_id:
		C1_ID: return "C1"
		C2_ID: return "C2"
		C3_ID: return "C3"
		C4_ID: return "C4"
		C5_ID: return "C5"
		C6_ID: return "C6"
	return "C?"


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
	# The LDtk Camera instance frames 336 x 160 world pixels.
	camera.zoom = Vector2(4.0, 4.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = -256
	camera.limit_top = -160
	camera.limit_right = 720
	camera.limit_bottom = 912
	_player.add_child(camera)


func _draw() -> void:
	for entry: Dictionary in _visual_rectangles:
		var rect := entry["rect"] as Rect2
		var color := entry["color"] as Color
		draw_rect(rect, color)
	for entry: Dictionary in _entity_labels:
		draw_string(ThemeDB.fallback_font, entry["position"] as Vector2, String(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)
