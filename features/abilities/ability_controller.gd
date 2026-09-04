class_name AbilityController
extends Node
## Owns mutually-exclusive held ability state. Vine behavior is added separately.

const LEG_EXTENSION_OFFSET := 36.0

signal ability_state_changed(label: StringName)
signal feedback_requested(message: String)
signal primary_ability_requested(ability_id: StringName)

var _player: Player
var _movement: MovementController
var _forms: FormController
var _leg_area: Area2D
var _rooted: bool = false
var _leg_extended: bool = false
var _vine_anchor: Node2D
var _leg_direction := Vector2.UP
var _standalone_form: FormDefinition


func setup(
	player: Variant = null,
	movement: MovementController = null,
	forms: FormController = null,
	leg_area: Area2D = null
) -> void:
	if player is FormDefinition:
		_standalone_form = player
		return
	_player = player
	_movement = movement
	_forms = forms
	_leg_area = leg_area
	if _leg_area != null:
		_leg_area.monitoring = false


func tick() -> void:
	if (_rooted or _leg_extended) and (_player == null or not _player.is_on_floor()):
		cancel_all()


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
	else:
		return try_root()


func set_leg_extension_direction(direction: Vector2) -> void:
	if _standalone_form != null:
		_leg_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO
		return
	if not _rooted:
		return
	var next_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO
	if next_direction.is_zero_approx():
		if _leg_extended:
			stop_secondary()
		_leg_direction = Vector2.ZERO
		return
	if not _leg_extended:
		if _leg_area == null or _player == null or not _player.set_leg_extension_active(true):
			feedback_requested.emit("上方空间不足，无法伸腿")
			return
		_leg_extended = true
		_leg_area.set_deferred("monitoring", true)
		_movement.set_leg_extended(true)
		ability_state_changed.emit(&"legs")
	_leg_direction = next_direction
	_leg_area.position = next_direction * LEG_EXTENSION_OFFSET
	_leg_area.rotation = next_direction.angle() + PI * 0.5


func try_root() -> bool:
	if _forms == null or _movement == null or _player == null:
		return false
	if _rooted:
		return true
	var form := _forms.get_current()
	if form == null or not form.can_root or not _player.is_on_floor() or _leg_extended:
		feedback_requested.emit("人形体在地面上才能扎根")
		return false
	_rooted = true
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
	if not _player.set_leg_extension_active(true):
		feedback_requested.emit("上方空间不足，无法伸腿")
		return false
	_leg_extended = true
	_leg_direction = Vector2.UP
	_leg_area.position = _leg_direction * LEG_EXTENSION_OFFSET
	_leg_area.rotation = 0.0
	_leg_area.set_deferred("monitoring", true)
	_movement.set_leg_extended(true)
	ability_state_changed.emit(&"legs")
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
	if not _leg_extended:
		return
	_leg_extended = false
	if _leg_area != null:
		_leg_area.set_deferred("monitoring", false)
		_leg_area.position = Vector2(0.0, -LEG_EXTENSION_OFFSET)
		_leg_area.rotation = 0.0
	if _movement != null:
		_movement.set_leg_extended(false)
	if _player != null:
		_player.set_leg_extension_active(false)
	_leg_direction = Vector2.UP
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


func get_vine_anchor() -> Node2D:
	return _vine_anchor if is_vine_attached() else null


func leg_area() -> Area2D:
	return _leg_area


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
	var query := PhysicsRayQueryParameters2D.create(
		_player.global_position,
		candidate.global_position,
		1
	)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return candidate is CollisionObject2D and hit.get("collider") == candidate
