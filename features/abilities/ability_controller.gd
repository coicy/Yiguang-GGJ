class_name AbilityController
extends Node
## Owns mutually-exclusive held ability state. Vine behavior is added separately.

const MAX_LEG_BODY_LENGTHS := 4.0
const LEG_TIP_COLLISION_SIZE := Vector2(24.0, 24.0)
const DIRECTION_EPSILON := 0.1
const VINE_ENDPOINT_TOLERANCE := 20.0
const LEG_WAYPOINT_TOLERANCE := 2.0
const VINE_MAX_RANGE := 300.0

signal ability_state_changed(label: StringName)
signal feedback_requested(message: String)
signal primary_ability_requested(ability_id: StringName)

@export_group("Vine")
@export var vine_climb_clearance: float = 14.0
@export var vine_climb_vertical_search: float = 160.0
@export var vine_climb_route_search: float = 128.0
@export var vine_climb_probe_step: float = 4.0
@export_range(1.0, 90.0, 1.0) var vine_aim_cone_degrees: float = 24.0

@export_group("Leg Extension")
@export var leg_extension_speed: float = 160.0
@export var leg_retraction_speed: float = 240.0
@export var leg_push_speed: float = 220.0

var _player: Player
var _movement: MovementController
var _forms: FormController
var _leg_area: Area2D
var _leg_collision_shape: CollisionShape2D
var _rooted: bool = false
var _leg_extended: bool = false
var _vine_anchor: Node2D
var _vine_aim_global_position := Vector2.ZERO
var _has_vine_aim_position: bool = false
var _vine_climb_requested: bool = false
var _leg_direction := Vector2.UP
var _camera_intent: Vector2 = Vector2.ZERO
var _last_leg_direction := Vector2.UP
var _leg_length: float = 0.0
var _leg_anchor_global_position := Vector2.ZERO
var _leg_corners_world: Array[Vector2] = []
var _retracting: bool = false
var _retraction_target := Vector2.ZERO
var _retraction_vector_before_move := Vector2.ZERO
var _standalone_form: FormDefinition


func setup(
	player: Variant = null,
	movement: MovementController = null,
	forms: FormController = null,
	leg_area: Area2D = null,
	leg_collision_shape: CollisionShape2D = null
) -> void:
	if player is FormDefinition:
		_standalone_form = player
		return
	_player = player
	_movement = movement
	_forms = forms
	_leg_area = leg_area
	_leg_collision_shape = leg_collision_shape
	if _leg_area != null:
		_leg_area.monitoring = false


func tick(delta: float = 0.0) -> void:
	_camera_intent = Vector2.ZERO
	if _player == null or _movement == null:
		return
	if _vine_climb_requested:
		_vine_climb_requested = false
		_try_climb_vine()
	if not _rooted:
		_retract_leg(delta)
		return
	if _leg_direction.is_zero_approx():
		_retract_leg(delta)
	else:
		_extend_leg(delta)


func post_movement_update() -> void:
	if is_vine_attached() and not _movement.is_vine_attached():
		stop_primary()
	if _player == null or not _rooted or not _leg_extended:
		return
	if _retracting:
		_finish_retraction_waypoint_if_reached()
	else:
		_enforce_max_leg_length()
	_update_leg_length()
	_update_leg_area()


func start_primary() -> bool:
	var form := _current_form()
	if form == null:
		return false
	if _standalone_form != null:
		if form.can_use_vine:
			primary_ability_requested.emit(&"vine_pull")
			return true
		_rooted = form.can_root
		return _rooted
	if form.can_use_vine:
		return true if is_vine_attached() else try_attach_vine()
	return true if _rooted else try_root()


func toggle_primary() -> bool:
	var form := _current_form()
	if _standalone_form != null:
		if form.can_use_vine:
			primary_ability_requested.emit(&"vine_pull")
			return true
		if _rooted:
			_rooted = false
			_leg_direction = Vector2.ZERO
		else:
			_rooted = true
		return true
	if form != null and form.can_use_vine:
		if is_vine_attached():
			stop_primary()
		else:
			return try_attach_vine()
		return true
	if _rooted:
		stop_primary()
		return true
	return try_root()


func set_vine_aim_global_position(global_position: Vector2) -> void:
	_vine_aim_global_position = global_position
	_has_vine_aim_position = true


func set_leg_extension_direction(direction: Vector2) -> void:
	if _standalone_form != null:
		_leg_direction = _cardinal_direction(direction)
		return
	if not _rooted:
		_leg_direction = Vector2.ZERO
		return
	var next_direction := _cardinal_direction(direction)
	if next_direction.is_zero_approx():
		_leg_direction = Vector2.ZERO
		return
	if not _leg_direction.is_zero_approx() and not next_direction.is_equal_approx(_leg_direction):
		if absf(_leg_direction.dot(next_direction)) > DIRECTION_EPSILON:
			return
		_add_corner_at_tip()
	elif _leg_direction.is_zero_approx() and _leg_length > 0.0:
		_add_corner_at_tip()
	_leg_direction = next_direction
	_last_leg_direction = next_direction
	_update_leg_area()


func try_root() -> bool:
	if _forms == null or _movement == null or _player == null:
		return false
	if _rooted:
		return true
	var form := _forms.get_current()
	if form == null or not form.can_root or not _player.can_root_here() or _leg_extended:
		feedback_requested.emit("人形体在地面上才能扎根")
		return false
	_rooted = true
	_leg_anchor_global_position = _player.global_position
	_movement.set_rooted(true)
	ability_state_changed.emit(&"rooted")
	return true


func try_extend_legs() -> bool:
	if _forms == null or _movement == null or _player == null or _leg_area == null:
		return false
	if _leg_extended:
		return true
	var form := _forms.get_current()
	if form == null or not form.can_extend_legs or not _player.is_on_floor() or _rooted:
		feedback_requested.emit("人形体在地面上才能伸腿")
		return false
	_leg_direction = Vector2.UP
	_last_leg_direction = _leg_direction
	_update_leg_area()
	return true


func try_attach_vine() -> bool:
	if _forms == null or _movement == null or _player == null:
		return false
	var form := _forms.get_current()
	if form == null or not form.can_use_vine or _rooted or _leg_extended:
		return false
	var aimed_anchor := _aimed_visible_anchor(VINE_MAX_RANGE)
	if aimed_anchor == null:
		feedback_requested.emit("鼠标方向没有可连接的藤蔓锚点")
		return false
	_vine_anchor = aimed_anchor
	_movement.attach_vine(aimed_anchor, _player.global_position.distance_to(aimed_anchor.global_position))
	ability_state_changed.emit(&"vine")
	return true


func request_vine_climb() -> void:
	if is_vine_attached() and not _movement.is_vine_climbing():
		_vine_climb_requested = true


func _try_climb_vine() -> void:
	if not is_vine_attached():
		return
	var mounting_bodies := _find_vine_mounting_bodies()
	for body: CollisionObject2D in mounting_bodies:
		_player.add_collision_exception_with(body)
	var route := _find_vine_climb_route()
	if route.is_empty():
		for body: CollisionObject2D in mounting_bodies:
			_player.remove_collision_exception_with(body)
		feedback_requested.emit("环上方或移动路径被挡住了")
		return
	_movement.request_vine_climb(route, mounting_bodies)


func _find_vine_mounting_bodies() -> Array[CollisionObject2D]:
	var probe := CircleShape2D.new()
	var form := _current_form()
	var half_width := form.collision_size.x * 0.5 if form != null else 14.0
	probe.radius = vine_climb_clearance + half_width + 2.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.transform = Transform2D(0.0, _vine_anchor.global_position)
	query.collision_mask = _player.collision_mask
	query.exclude = [_player.get_rid()]
	var bodies: Array[CollisionObject2D] = []
	for hit: Dictionary in _player.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider := hit.get("collider") as CollisionObject2D
		if collider != null and not collider in bodies:
			bodies.append(collider)
	return bodies


func _find_vine_climb_route() -> Array[Vector2]:
	var step := maxf(vine_climb_probe_step, 1.0)
	var initial_target := _vine_anchor.global_position + Vector2(0.0, -vine_climb_clearance)
	var initial_hits := _vine_climb_position_hits(initial_target)
	if not initial_hits.is_empty() and not _hits_only_anchor_parent(initial_hits):
		return []
	var vertical_steps := ceili(maxf(vine_climb_vertical_search, 0.0) / step)
	for vertical_index: int in range(vertical_steps + 1 if not initial_hits.is_empty() else 1):
		var target := initial_target + Vector2.UP * step * vertical_index
		var target_hits := _vine_climb_position_hits(target)
		if not target_hits.is_empty():
			if not _hits_only_anchor_parent(target_hits):
				return []
			continue
		var direct_route: Array[Vector2] = [target]
		if _is_vine_climb_route_clear(direct_route):
			return direct_route
		var detour := _find_vine_climb_detour(target, step)
		if not detour.is_empty():
			return detour
	return []


func _find_vine_climb_detour(target: Vector2, step: float) -> Array[Vector2]:
	var form := _current_form()
	var half_width := form.collision_size.x * 0.5 if form != null else 14.0
	var first_side := signf(_player.global_position.x - _vine_anchor.global_position.x)
	if is_zero_approx(first_side):
		first_side = 1.0
	var side_order: Array[float] = [first_side, -first_side]
	var minimum_offset := half_width + vine_climb_clearance
	var route_steps := ceili(maxf(vine_climb_route_search - minimum_offset, 0.0) / step)
	for route_index: int in range(route_steps + 1):
		var horizontal_offset := minimum_offset + route_index * step
		for side: float in side_order:
			var side_x := _vine_anchor.global_position.x + side * horizontal_offset
			var lower_corner := Vector2(side_x, _player.global_position.y)
			var upper_corner := Vector2(side_x, target.y)
			var route: Array[Vector2] = [lower_corner, upper_corner, target]
			if (
				_can_occupy_vine_climb_position(lower_corner)
				and _can_occupy_vine_climb_position(upper_corner)
				and _is_vine_climb_route_clear(route)
			):
				return route
	return []


func _can_occupy_vine_climb_position(target: Vector2) -> bool:
	return _vine_climb_position_hits(target).is_empty()


func _vine_climb_position_hits(target: Vector2) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _player.collision_shape.shape
	query.transform = _player.collision_shape.global_transform
	query.transform.origin += target - _player.global_position
	query.collision_mask = _player.collision_mask
	query.exclude = [_player.get_rid()]
	return _player.get_world_2d().direct_space_state.intersect_shape(query, 8)


func _hits_only_anchor_parent(hits: Array[Dictionary]) -> bool:
	var anchor_parent := _vine_anchor.get_parent()
	if not anchor_parent is CollisionObject2D:
		return false
	for hit: Dictionary in hits:
		if hit.get("collider") != anchor_parent:
			return false
	return true


func _is_vine_climb_route_clear(route: Array[Vector2]) -> bool:
	var segment_start := _player.global_position
	for segment_end: Vector2 in route:
		var transform := _player.global_transform
		transform.origin = segment_start
		if _player.test_move(transform, segment_end - segment_start):
			return false
		segment_start = segment_end
	return true


func stop_primary() -> void:
	_vine_climb_requested = false
	var changed := false
	if _leg_extended:
		stop_secondary()
	if _rooted:
		_rooted = false
		if _movement != null:
			_movement.set_rooted(false)
		changed = true
	if _vine_anchor != null:
		_vine_anchor = null
		if _movement != null:
			_movement.detach_vine()
		changed = true
	if changed:
		ability_state_changed.emit(&"none")


func stop_secondary() -> void:
	if not _leg_extended and _leg_length <= 0.0:
		if _movement != null:
			_movement.set_leg_push(Vector2.ZERO, 0.0)
		_leg_direction = Vector2.ZERO
		return
	_leg_length = 0.0
	_leg_corners_world.clear()
	_leg_extended = false
	_retracting = false
	if _leg_area != null:
		_leg_area.set_deferred("monitoring", false)
		_leg_area.position = Vector2.ZERO
		_leg_area.rotation = 0.0
	if _movement != null:
		_movement.set_leg_push(Vector2.ZERO, 0.0)
		_movement.set_leg_extended(false)
	_leg_direction = Vector2.ZERO
	ability_state_changed.emit(&"none")


func cancel_all() -> void:
	stop_primary()
	stop_secondary()
	_leg_direction = Vector2.ZERO


func is_rooted() -> bool:
	return _rooted


func is_leg_extended() -> bool:
	return _leg_extended


func is_vine_attached() -> bool:
	return _vine_anchor != null and is_instance_valid(_vine_anchor)


func get_leg_extension_direction() -> Vector2:
	return _leg_direction


## Only active extension steers the camera; automatic retraction does not.
func get_camera_intent() -> Vector2:
	return _camera_intent


func get_leg_length() -> float:
	return _leg_length


func get_max_leg_length() -> float:
	var form := _current_form()
	return (form.collision_size.y if form != null else 40.0) * MAX_LEG_BODY_LENGTHS


func get_leg_path() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	if _leg_length <= 0.0 or _player == null:
		return points
	for index in range(_leg_corners_world.size() - 1, -1, -1):
		points.append(_player.to_local(_leg_corners_world[index]))
	points.append(_player.to_local(_leg_anchor_global_position))
	return points


func get_leg_anchor_global_position() -> Vector2:
	return _leg_anchor_global_position


func get_vine_anchor() -> Node2D:
	return _vine_anchor if is_vine_attached() else null


func leg_area() -> Area2D:
	return _leg_area


func _extend_leg(delta: float) -> void:
	_retracting = false
	_update_leg_length()
	if _leg_length < get_max_leg_length():
		_start_leg_if_needed()
		var extension_speed := minf(leg_push_speed, leg_extension_speed)
		if extension_speed > 0.0:
			_camera_intent = _leg_direction
		_movement.set_leg_push(_leg_direction, extension_speed)
	else:
		_movement.set_leg_push(Vector2.ZERO, 0.0)
	_update_leg_area()


func _retract_leg(delta: float) -> void:
	if _leg_length <= 0.0:
		if _leg_extended:
			stop_secondary()
		return
	_retracting = true
	_retraction_target = (
		_leg_corners_world[_leg_corners_world.size() - 1]
		if not _leg_corners_world.is_empty()
		else _leg_anchor_global_position
	)
	_retraction_vector_before_move = _retraction_target - _player.global_position
	if _retraction_vector_before_move.length() <= LEG_WAYPOINT_TOLERANCE:
		_finish_retraction_waypoint_if_reached()
		return
	_movement.set_leg_push(_retraction_vector_before_move.normalized(), leg_retraction_speed)


func _start_leg_if_needed() -> void:
	if _leg_extended:
		return
	_leg_extended = true
	_movement.set_leg_extended(true)
	if _leg_area != null:
		_leg_area.set_deferred("monitoring", true)
	ability_state_changed.emit(&"legs")


func _update_leg_area() -> void:
	if _leg_area == null:
		return
	_leg_area.global_position = _leg_anchor_global_position
	_leg_area.rotation = _last_leg_direction.angle()
	if _leg_collision_shape != null:
		var shape := _leg_collision_shape.shape as RectangleShape2D
		if shape == null:
			shape = RectangleShape2D.new()
			_leg_collision_shape.shape = shape
		shape.size = LEG_TIP_COLLISION_SIZE


func _add_corner_at_tip() -> void:
	var corner := _player.global_position
	var previous := (
		_leg_corners_world[_leg_corners_world.size() - 1]
		if not _leg_corners_world.is_empty()
		else _leg_anchor_global_position
	)
	if previous.distance_to(corner) > LEG_WAYPOINT_TOLERANCE:
		_leg_corners_world.append(corner)


func _update_leg_length() -> void:
	var total := 0.0
	var previous := _leg_anchor_global_position
	for corner in _leg_corners_world:
		total += previous.distance_to(corner)
		previous = corner
	if _player != null:
		total += previous.distance_to(_player.global_position)
	_leg_length = total


func _enforce_max_leg_length() -> void:
	var fixed_length := 0.0
	var segment_origin := _leg_anchor_global_position
	for corner in _leg_corners_world:
		fixed_length += segment_origin.distance_to(corner)
		segment_origin = corner
	var allowed_segment := maxf(0.0, get_max_leg_length() - fixed_length)
	var segment := _player.global_position - segment_origin
	if segment.length() <= allowed_segment or segment.is_zero_approx():
		return
	var segment_direction := segment.normalized()
	var target := segment_origin + segment_direction * allowed_segment
	_player.move_and_collide(target - _player.global_position)
	# Remove only the velocity pushing away from the anchor. Tangential velocity
	# remains available for future path shapes and collision responses.
	var outward_speed := _player.velocity.dot(segment_direction)
	if outward_speed > 0.0:
		_player.velocity -= segment_direction * outward_speed
	_movement.set_leg_push(Vector2.ZERO, 0.0)


func _finish_retraction_waypoint_if_reached() -> void:
	var remaining := _retraction_target - _player.global_position
	var reached := remaining.length() <= LEG_WAYPOINT_TOLERANCE
	if not reached and not _retraction_vector_before_move.is_zero_approx():
		reached = _retraction_vector_before_move.dot(remaining) <= 0.0
	if not reached:
		return
	if not remaining.is_zero_approx():
		_player.move_and_collide(remaining)
	if not _leg_corners_world.is_empty():
		_leg_corners_world.pop_back()
		_update_leg_length()
		return
	stop_secondary()


func _cardinal_direction(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	if absf(direction.y) > absf(direction.x):
		return Vector2(0.0, signf(direction.y))
	return _leg_direction if not _leg_direction.is_zero_approx() else Vector2.RIGHT


func _aimed_visible_anchor(max_range: float) -> Node2D:
	var aim_position := _vine_aim_global_position
	if not _has_vine_aim_position:
		aim_position = _player.get_global_mouse_position()
	var aim_vector := aim_position - _player.global_position
	if aim_vector.is_zero_approx():
		return null
	var aim_direction := aim_vector.normalized()
	var max_angle := deg_to_rad(vine_aim_cone_degrees)
	var selected: Node2D
	var selected_angle: float = INF
	var selected_distance := max_range
	for candidate_node: Node in _player.get_tree().get_nodes_in_group("vine_anchor"):
		var candidate := candidate_node as Node2D
		if candidate == null:
			continue
		var to_candidate := candidate.global_position - _player.global_position
		var distance := to_candidate.length()
		if distance <= 0.0 or distance > max_range:
			continue
		var angle := absf(aim_direction.angle_to(to_candidate.normalized()))
		if angle > max_angle or not _has_clear_path(candidate):
			continue
		if angle < selected_angle - 0.001 or (
			is_equal_approx(angle, selected_angle) and distance < selected_distance
		):
			selected = candidate
			selected_angle = angle
			selected_distance = distance
	return selected


func _current_form() -> FormDefinition:
	if _standalone_form != null:
		return _standalone_form
	return _forms.get_current() if _forms != null else null


func _has_clear_path(candidate: Node2D) -> bool:
	var origin := _player.global_position
	var form := _current_form()
	if form != null:
		origin += Vector2(0.0, -form.collision_size.y * 0.5)
	var query := PhysicsRayQueryParameters2D.create(
		origin,
		candidate.global_position,
		1
	)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Variant = hit.get("collider")
	if candidate is CollisionObject2D and collider == candidate:
		return true
	# Rings mounted on a moving cube intentionally sit on its solid surface.
	# The cube is therefore a valid line-of-sight endpoint for its child Ring.
	if collider == candidate.get_parent():
		return true
	var hit_position: Vector2 = hit.get("position", Vector2.INF)
	return hit_position.distance_to(candidate.global_position) <= VINE_ENDPOINT_TOLERANCE
