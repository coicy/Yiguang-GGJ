class_name AbilityController
extends Node
## Owns mutually-exclusive held ability state. Vine behavior is added separately.

const MAX_LEG_BODY_LENGTHS := 4.0
const LEG_TIP_COLLISION_SIZE := Vector2(24.0, 24.0)
const DIRECTION_EPSILON := 0.1
const VINE_ENDPOINT_TOLERANCE := 20.0
const LEG_WAYPOINT_TOLERANCE := 2.0

signal ability_state_changed(label: StringName)
signal feedback_requested(message: String)
signal primary_ability_requested(ability_id: StringName)

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
var _leg_direction := Vector2.UP
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
	if _player == null or _movement == null:
		return
	if not _rooted:
		_retract_leg(delta)
		return
	if _leg_direction.is_zero_approx():
		_retract_leg(delta)
	else:
		_extend_leg(delta)


func post_movement_update() -> void:
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
	var nearest := _nearest_visible_anchor(300.0)
	if nearest == null:
		feedback_requested.emit("附近没有可连接的藤蔓锚点")
		return false
	_vine_anchor = nearest
	_movement.attach_vine(nearest, _player.global_position.distance_to(nearest.global_position))
	ability_state_changed.emit(&"vine")
	return true


func stop_primary() -> void:
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
	var target := segment_origin + segment.normalized() * allowed_segment
	_player.move_and_collide(target - _player.global_position)
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


func _nearest_visible_anchor(max_range: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := max_range
	for candidate_node: Node in _player.get_tree().get_nodes_in_group("vine_anchor"):
		var candidate := candidate_node as Node2D
		if candidate == null:
			continue
		var distance := _player.global_position.distance_to(candidate.global_position)
		if distance > nearest_distance or not _has_clear_path(candidate):
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest


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
